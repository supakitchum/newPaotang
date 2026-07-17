import 'package:customer_flutter/core/utils/api_payload.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_deep_link.dart';
import 'package:customer_flutter/core/utils/api_errors.dart';
import 'package:customer_flutter/core/utils/asset_url.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/security/web_privacy_mode.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/presentation/activity_claim_localization.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/profile/data/line_notification_models.dart';
import 'package:customer_flutter/features/profile/data/biometric_device_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_models.dart';
import 'package:customer_flutter/features/reward_claims/presentation/reward_claim_localization.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/stores/data/store_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/presentation/ticket_localization.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    await initializeDateFormatting('en_US');
  });

  test('unwrapDataList reads Laravel resource list shape', () {
    final rows = unwrapDataList({
      'data': [
        {'id': 1},
        {'id': 2},
      ],
      'meta': {'total': 2},
    });

    expect(rows.map((row) => row['id']), [1, 2]);
  });

  test('unwrapDataList reads legacy result list shape', () {
    final rows = unwrapDataList({
      'code': 0,
      'result': [
        {'id': 'a'},
      ],
    });

    expect(rows.single['id'], 'a');
  });

  test('unwrapDataList reads resource list shapes', () {
    final directResource = unwrapDataList({
      'resource': [
        {'id': 'res_1'},
      ],
    });
    final nestedResource = unwrapDataList({
      'resource': {
        'data': [
          {'id': 'res_nested'},
        ],
      },
    });
    final nestedItems = unwrapDataList({
      'data': {
        'items': [
          {'id': 'item_nested'},
        ],
      },
    });

    expect(directResource.single['id'], 'res_1');
    expect(nestedResource.single['id'], 'res_nested');
    expect(nestedItems.single['id'], 'item_nested');
  });

  test('unwrapPayload reads result and resource object shapes', () {
    expect(
      unwrapPayload({
        'result': {'token': 'abc'},
      })['token'],
      'abc',
    );
    expect(
      unwrapPayload({
        'resource': {'id': 10},
      })['id'],
      10,
    );
  });

  test('unwrapMeta reads direct and nested pagination metadata', () {
    expect(
      unwrapMeta({
        'meta': {'next_cursor': 'direct'},
      })['next_cursor'],
      'direct',
    );
    expect(
      unwrapMeta({
        'resource': {
          'data': const <Object>[],
          'meta': {'next_cursor': 'resource'},
        },
      })['next_cursor'],
      'resource',
    );
    expect(
      unwrapMeta({
        'result': {
          'items': const <Object>[],
          'meta': {'current_page': 2, 'last_page': 5},
        },
      })['last_page'],
      5,
    );
  });

  test('api error parser maps SMS OTP optional provider details', () {
    final optional = ApiErrorInfo.fromObject({
      'error': {
        'code': 'sms_otp_provider_not_configured',
        'message': 'SMS OTP provider is not configured.',
        'details': {'provider_required': false},
      },
    });
    final required = ApiErrorInfo.fromObject({
      'error': {
        'code': 'sms_otp_provider_not_configured',
        'details': {'provider_required': true},
      },
    });

    expect(optional.isSmsOtpProviderNotConfigured, isTrue);
    expect(optional.providerRequired, isFalse);
    expect(optional.isOptionalSmsOtpProviderMissing, isTrue);
    expect(required.providerRequired, isTrue);
    expect(required.isOptionalSmsOtpProviderMissing, isFalse);
  });

  test('api error parser supports top-level and validation shapes', () {
    final topLevel = ApiErrorInfo.fromObject({
      'code': 'maintenance_active',
      'message': 'Maintenance is active.',
      'details': {'reason': 'deploy'},
    });
    final validation = ApiErrorInfo.fromObject({
      'errors': {
        'phone': ['Phone is invalid.'],
      },
    });
    final stringError = ApiErrorInfo.fromObject({
      'error': 'Provider not configured.',
    });

    expect(topLevel.code, 'maintenance_active');
    expect(topLevel.message, 'Maintenance is active.');
    expect(topLevel.details['reason'], 'deploy');
    expect(validation.message, 'Phone is invalid.');
    expect(validation.details['phone'], ['Phone is invalid.']);
    expect(stringError.message, 'Provider not configured.');
  });

  test('api error parser detects expired sessions without hiding bad login',
      () {
    final expiredRequest = RequestOptions(path: '/customer/auth/pin/status');
    final expired = ApiErrorInfo.fromObject(
      DioException(
        requestOptions: expiredRequest,
        response: Response<Map<String, dynamic>>(
          requestOptions: expiredRequest,
          statusCode: 401,
          data: {'message': 'Unauthenticated.'},
        ),
      ),
    );
    final invalidLoginRequest = RequestOptions(path: '/customer/auth/login');
    final invalidLogin = ApiErrorInfo.fromObject(
      DioException(
        requestOptions: invalidLoginRequest,
        response: Response<Map<String, dynamic>>(
          requestOptions: invalidLoginRequest,
          statusCode: 401,
          data: {'message': 'Invalid credentials.'},
        ),
      ),
    );

    expect(expired.isAuthenticationExpired, isTrue);
    expect(expired.operationalRedirectPath, '/login');
    expect(invalidLogin.isAuthenticationExpired, isFalse);
    expect(invalidLogin.operationalRedirectPath, isNull);
    expect(invalidLogin.message, 'Invalid credentials.');
  });

  test('api error parser accepts backend authentication_required outside login',
      () {
    final protectedRequest = RequestOptions(path: '/customer/auth/pin/status');
    final protectedError = ApiErrorInfo.fromObject(
      DioException(
        requestOptions: protectedRequest,
        response: Response<Map<String, dynamic>>(
          requestOptions: protectedRequest,
          statusCode: 401,
          data: const {
            'error': {
              'code': 'authentication_required',
              'message':
                  'Authentication token is missing, invalid, expired, or revoked.',
            },
          },
        ),
      ),
    );
    final loginRequest = RequestOptions(path: '/customer/auth/login');
    final loginError = ApiErrorInfo.fromObject(
      DioException(
        requestOptions: loginRequest,
        response: Response<Map<String, dynamic>>(
          requestOptions: loginRequest,
          statusCode: 401,
          data: const {
            'error': {
              'code': 'authentication_required',
              'message':
                  'Authentication token is missing, invalid, expired, or revoked.',
            },
          },
        ),
      ),
    );

    expect(protectedError.isAuthenticationExpired, isTrue);
    expect(protectedError.operationalRedirectPath, '/login');
    expect(loginError.isAuthenticationExpired, isFalse);
    expect(loginError.operationalRedirectPath, isNull);
  });

  test('api error parser builds operational redirect paths', () {
    final suspended = ApiErrorInfo.fromObject({
      'error': {
        'code': 'customer_suspended',
        'details': {
          'suspension': {
            'reason': 'ตรวจสอบบัญชี',
            'suspended_until': '2026-07-01T10:00:00+07:00',
            'is_permanent': false,
          },
        },
      },
    });
    final permanent = ApiErrorInfo.fromObject({
      'error': {
        'code': 'customer_suspended',
        'details': {
          'reason': 'ปิดบัญชี',
          'is_permanent': true,
        },
      },
    });
    final camelCase = ApiErrorInfo.fromObject({
      'error': {
        'code': 'customer_suspended',
        'details': {
          'accountSuspension': {
            'suspensionReason': 'ตรวจสอบความเสี่ยง',
            'suspendedUntil': '2026-07-02T03:00:00Z',
            'isPermanent': 'yes',
          },
        },
      },
    });

    expect(suspended.operationalRedirectPath, contains('/account-suspended'));
    expect(suspended.operationalRedirectPath, contains('reason='));
    expect(suspended.operationalRedirectPath, contains('suspended_until='));
    expect(permanent.operationalRedirectPath, contains('permanent=1'));
    final camelUri = Uri.parse(camelCase.operationalRedirectPath!);
    expect(camelUri.queryParameters['reason'], 'ตรวจสอบความเสี่ยง');
    expect(
      camelUri.queryParameters['suspended_until'],
      '2026-07-02T03:00:00Z',
    );
    expect(camelUri.queryParameters['permanent'], '1');
    expect(
      ApiErrorInfo.fromObject({
        'error': {'code': 'maintenance_active'},
      }).operationalRedirectPath,
      '/maintenance',
    );
    expect(
      ApiErrorInfo.fromObject({
        'error': {'code': 'pin_required'},
      }).operationalRedirectPath,
      '/pin',
    );
  });

  test('customer session parser supports token aliases and pin flags', () {
    final session = CustomerSession.fromJson({
      'token': 'access',
      'refresh_token': 'refresh',
      'user': {'id': 'cus_1', 'pin_required': true},
    });

    expect(session.accessToken, 'access');
    expect(session.refreshToken, 'refresh');
    expect(session.pinRequired, isTrue);
    expect(session.pinSetupRequired, isFalse);
    expect(session.customerId, 'cus_1');

    final setupSession = CustomerSession.fromJson({
      'access_token': 'access',
      'user': {'id': 'cus_2', 'pin_setup_required': true},
    });

    expect(setupSession.pinRequired, isTrue);
    expect(setupSession.pinSetupRequired, isTrue);
  });

  test('customer session parser preserves recursive auth wrappers', () {
    final session = CustomerSession.fromJson({
      'meta': {'request_id': 'req_auth_recursive'},
      'data': {
        'resource': {
          'customerSession': {
            'accessToken': 'access-recursive',
            'refreshToken': 'refresh-recursive',
            'pinSetupRequired': true,
            'customer': {'customerId': 'cus_recursive'},
          },
        },
      },
    });

    expect(session.accessToken, 'access-recursive');
    expect(session.refreshToken, 'refresh-recursive');
    expect(session.pinRequired, isTrue);
    expect(session.pinSetupRequired, isTrue);
    expect(session.customerId, 'cus_recursive');
  });

  test('otp parsers support detail wrapped fields', () {
    final requested = OtpRequestResult.fromJson({
      'details': {'phone_masked': '08xxxxx999', 'resend_after_seconds': '45'},
    });
    final verified = OtpVerifyResult.fromJson({
      'otp_verification_token': 'otp-token',
    });

    expect(requested.phoneMasked, '08xxxxx999');
    expect(requested.resendAfterSeconds, 45);
    expect(verified.verificationToken, 'otp-token');
  });

  test('otp parsers preserve recursive request and verification wrappers', () {
    final requested = OtpRequestResult.fromJson({
      'data': {
        'resource': {
          'otpRequest': {
            'details': {
              'phoneMasked': '08xxxxx777',
              'resendAfterSeconds': '30',
            },
          },
        },
      },
    });
    final verified = OtpVerifyResult.fromJson({
      'result': {
        'resource': {
          'otpVerification': {
            'otpVerificationToken': 'otp-token-recursive',
          },
        },
      },
    });

    expect(requested.phoneMasked, '08xxxxx777');
    expect(requested.resendAfterSeconds, 30);
    expect(verified.verificationToken, 'otp-token-recursive');
  });

  test('otp verification parser accepts production token aliases', () {
    final verified = OtpVerifyResult.fromJson({
      'data': {
        'resource': {
          'otpVerify': {'otpToken': 'otp-token-alias'},
        },
      },
    });

    expect(verified.verificationToken, 'otp-token-alias');
  });

  test('otp parsers accept production reset/register alias envelopes', () {
    final requested = OtpRequestResult.fromJson({
      'data': {
        'pinReset': {
          'otpRequestResult': {
            'mobileNumberMasked': '08xxxxx444',
            'rateLimit': {'retryAfterSeconds': '42'},
          },
        },
      },
    });
    final verified = OtpVerifyResult.fromJson({
      'payload': {
        'passwordReset': {
          'otpVerifyResult': {'verificationId': 'verify-id-42'},
        },
      },
    });

    expect(requested.phoneMasked, '08xxxxx444');
    expect(requested.resendAfterSeconds, 42);
    expect(verified.verificationToken, 'verify-id-42');
  });

  test('otp parsers accept contact delivery metadata aliases', () {
    final requested = OtpRequestResult.fromJson({
      'data': {
        'resource': {
          'otpRequest': {
            'recipient': {'maskedPhone': '08xxxxx555'},
            'delivery': {
              'channel': 'sms',
              'retryAfterSeconds': {'value': '45'},
            },
          },
        },
      },
    });
    final verified = OtpVerifyResult.fromJson({
      'data': {
        'resource': {
          'otpVerify': {
            'verification': {
              'token': {'value': 'verify-object-token'},
            },
          },
        },
      },
    });

    expect(requested.phoneMasked, '08xxxxx555');
    expect(requested.resendAfterSeconds, 45);
    expect(verified.verificationToken, 'verify-object-token');
  });

  test('line callback parser supports link required and session payloads', () {
    final linkRequired = SocialCallbackResult.fromJson({
      'line_link_required': true,
      'link_token': 'link-token',
      'line_profile': {
        'display_name': 'ดีทู',
        'picture_url': 'https://example.com/avatar.jpg',
      },
    });
    final signedIn = SocialCallbackResult.fromJson({
      'token': 'access',
      'refresh_token': 'refresh',
      'pin_required': true,
    });

    expect(linkRequired.lineLinkRequired, isTrue);
    expect(linkRequired.linkToken, 'link-token');
    expect(linkRequired.displayName, 'ดีทู');
    expect(signedIn.session?.accessToken, 'access');
    expect(signedIn.session?.pinRequired, isTrue);
  });

  test('social callback parser supports generic provider link payloads', () {
    final linkRequired = SocialCallbackResult.fromJson({
      'social_link_required': true,
      'provider': 'google',
      'social_link_token': 'social-token',
      'profile': {
        'display_name': 'Google Customer',
        'avatar_url': 'https://example.com/google.jpg',
      },
    });

    expect(linkRequired.provider, 'google');
    expect(linkRequired.lineLinkRequired, isTrue);
    expect(linkRequired.linkToken, 'social-token');
    expect(linkRequired.displayName, 'Google Customer');
    expect(linkRequired.pictureUrl, 'https://example.com/google.jpg');
  });

  test('social callback parser preserves recursive link and session wrappers',
      () {
    final linkRequired = SocialCallbackResult.fromJson({
      'data': {
        'resource': {
          'socialCallback': {
            'provider': 'google_oauth2',
            'socialLinkRequired': true,
            'socialLinkToken': 'google-recursive-link-token',
            'profile': {
              'displayName': 'Google Recursive',
              'avatarUrl': 'https://example.com/google-recursive.jpg',
            },
          },
        },
      },
    });
    final signedIn = SocialCallbackResult.fromJson({
      'result': {
        'resource': {
          'callback': {
            'provider': 'apple_login',
            'session': {
              'accessToken': 'apple-recursive-access',
              'refreshToken': 'apple-recursive-refresh',
              'pinRequired': true,
              'customer': {'id': 'cus_apple_recursive'},
            },
          },
        },
      },
    });

    expect(linkRequired.provider, 'google');
    expect(linkRequired.lineLinkRequired, isTrue);
    expect(linkRequired.linkToken, 'google-recursive-link-token');
    expect(linkRequired.displayName, 'Google Recursive');
    expect(
      linkRequired.pictureUrl,
      'https://example.com/google-recursive.jpg',
    );
    expect(signedIn.provider, 'apple');
    expect(signedIn.session?.accessToken, 'apple-recursive-access');
    expect(signedIn.session?.refreshToken, 'apple-recursive-refresh');
    expect(signedIn.session?.pinRequired, isTrue);
    expect(signedIn.session?.customerId, 'cus_apple_recursive');
  });

  test('social provider aliases normalize before routing to auth APIs', () {
    expect(normalizeSocialAuthProvider('line_login'), 'line');
    expect(normalizeSocialAuthProvider('line_oa'), 'line');
    expect(normalizeSocialAuthProvider('line_oauth'), 'line');
    expect(normalizeSocialAuthProvider('gmail'), 'google');
    expect(normalizeSocialAuthProvider('google_oauth2'), 'google');
    expect(normalizeSocialAuthProvider('apple_id'), 'apple');
    expect(normalizeSocialAuthProvider('apple_login'), 'apple');
    expect(normalizeSocialAuthProvider('sign_in_with_apple'), 'apple');

    final callback = SocialCallbackResult.fromJson({
      'provider': 'apple_id',
      'social_link_required': true,
      'social_link_token': 'apple-link-token',
    });

    expect(callback.provider, 'apple');
    expect(callback.linkToken, 'apple-link-token');
  });

  test('mobile bootstrap accepts grouped social and LINE config aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'authConfig': {
        'providers': {
          'line-login': {'status': 'ready', 'label': 'LINE Login'},
          'google.oauth2': {'available': 'on'},
          'apple-login': 'enabled',
        },
        'lineConfig': {
          'liff': {'id': 'root-liff', 'enabled': 'on'},
          'bot': {'basicId': '@root'},
          'friendUrl': 'https://line.example.test/root',
        },
      },
      'mobileConfig': {
        'socialLoginConfig': {
          'providers': [
            {'provider': 'line_oa', 'enabled': true, 'label': 'LINE duplicate'},
          ],
          'lineLogin': {
            'lineLiffId': 'mobile-liff',
            'lineAvailable': 'supported',
            'lineAddFriendUrl': 'https://line.example.test/mobile',
          },
        },
      },
    });

    expect(
      bootstrap.authProviders.map((provider) => provider.provider),
      ['line', 'google', 'apple'],
    );
    expect(bootstrap.authProviders.first.label, 'LINE Login');
    expect(bootstrap.line.configured, isTrue);
    expect(bootstrap.line.liffId, 'mobile-liff');
    expect(bootstrap.line.liffEnabled, isTrue);
    expect(bootstrap.line.botBasicId, '@root');
    expect(bootstrap.line.addFriendUrl, 'https://line.example.test/mobile');
  });

  test('mobile bootstrap maps maintenance fields', () {
    final bootstrap = MobileBootstrap.fromJson({
      'site': {'display_name': 'พบโชค', 'support_phone': '020000000'},
      'legal': {
        'terms_content': 'terms',
        'privacy_content': 'privacy',
        'privacy_policy_url': 'https://partner.example.com/privacy',
        'account_deletion_url': 'https://partner.example.com/delete-account',
      },
      'mobile': {
        'line': {
          'liff_id': '1234567890-AbCdEf',
          'liff_enabled': true,
          'bot_basic_id': '@demo',
          'add_friend_url': 'https://line.me/R/ti/p/@demo',
        },
        'realtime': {
          'enabled': true,
          'url': 'https://realtime.example.com',
          'key': 'customer-key',
          'auth_endpoint': '/customer/realtime/auth',
        },
        'biometric': {
          'enabled': true,
          'requires_pin_setup': true,
          'assertion_token_ttl_seconds': '240',
          'platforms': {
            'ios': ['face_id', 'touch_id'],
            'android': ['biometric_prompt'],
          },
        },
        'screen_security': {
          'android': {
            'flag_secure': true,
            'protect_recent_app_preview': true,
          },
          'ios': {
            'screenshot_policy': 'lock_and_blank',
            'screen_capture_overlay': true,
            'exit_app': false,
          },
          'web': {
            'sensitive_screen_mode': 'limited',
            'watermark_enabled': true,
          },
          'sensitive_routes': ['/pin', '/my-wallet'],
        },
        'feature_flags': {
          'screen_security_native': true,
          'native_biometric_unlock': true,
        },
      },
      'maintenance': {
        'active': true,
        'mode': 'full_site',
        'message': 'ปิดปรับปรุง',
        'expected_end_at': '2026-06-25T12:00:00+07:00',
        'retry_after_seconds': '120',
        'allowed_routes': ['/news*'],
        'blocked_route_patterns': ['/checkout*'],
      },
    });

    expect(bootstrap.siteName, 'พบโชค');
    expect(bootstrap.supportPhone, '020000000');
    expect(bootstrap.privacyContent, 'privacy');
    expect(bootstrap.privacyPolicyUrl, 'https://partner.example.com/privacy');
    expect(
      bootstrap.accountDeletionUrl,
      'https://partner.example.com/delete-account',
    );
    expect(bootstrap.maintenance.active, isTrue);
    expect(bootstrap.maintenance.mode, 'full_site');
    expect(bootstrap.maintenance.retryAfterSeconds, 120);
    expect(bootstrap.maintenance.blocksRoute('/news/notice'), isFalse);
    expect(bootstrap.maintenance.blocksRoute('/checkout/pending'), isTrue);
    expect(bootstrap.line.configured, isTrue);
    expect(bootstrap.line.liffId, '1234567890-AbCdEf');
    expect(bootstrap.line.addFriendUrl, 'https://line.me/R/ti/p/@demo');
    expect(bootstrap.realtime.configured, isTrue);
    expect(bootstrap.realtime.url, 'https://realtime.example.com');
    expect(bootstrap.realtime.key, 'customer-key');
    expect(bootstrap.biometric.assertionTokenTtlSeconds, 240);
    expect(bootstrap.biometric.supportsPlatform('ios'), isTrue);
    expect(bootstrap.screenSecurity.androidFlagSecure, isTrue);
    expect(bootstrap.screenSecurity.iosExitApp, isFalse);
    expect(bootstrap.screenSecurity.webWatermarkEnabled, isTrue);
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/my-wallet/ledger'),
      isTrue,
    );
    expect(bootstrap.featureFlags.enabled('screen_security_native'), isTrue);
  });

  test('mobile bootstrap accepts camelCase realtime and web security aliases',
      () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'displayName': 'ร้านค้าพาร์ทเนอร์',
        'supportPhone': '021111111',
      },
      'legalConfig': {
        'privacyContent': 'privacy camel',
        'privacyPolicyUrl': 'https://partner.example.com/privacy',
        'accountDeletionUrl': 'https://partner.example.com/delete-account',
      },
      'mobileConfig': {
        'realtimeConfig': {
          'enabled': 'true',
          'socketUrl': 'https://realtime.partner.example.com',
          'appKey': 'partner-realtime-key',
          'authEndpoint': '/customer/realtime/custom-auth',
          'protocol': '8',
          'clientName': 'partner-flutter',
        },
        'screenSecurity': {
          'android': {
            'flagSecure': 'false',
            'protectRecentAppPreview': 'true',
          },
          'ios': {
            'screenshotPolicy': 'overlay_only',
            'screenCaptureOverlay': 'false',
            'exitApp': 'true',
          },
          'web': {
            'sensitiveScreenMode': 'strict',
            'watermarkEnabled': 'true',
          },
          'sensitiveRoutes': [
            '/checkout',
            '/reward-claims',
            '/tenant-claims/:claimId',
            '/vip-secure/*',
            {
              'deepLink':
                  'customer://screen-security?returnUrl=https%3A%2F%2Fshop.example.test%2Fpurchase-history%2Ford_1%3Ftab%3Dreceipt',
            },
            {'hashRoute': '#/wallet-secure/123?tab=summary'},
          ],
        },
        'featureFlags': {
          'screen_security_native': 'true',
          'native_biometric_unlock': 'false',
        },
        'maintenanceMode': {
          'mode': 'checkout_payment_only',
          'allowedRoutes': [
            {'path': '/terms'},
          ],
          'routes': {
            'blocked': {
              '/profile/reward-bank*': {'enabled': 'true'},
            },
          },
        },
      },
      'maintenanceConfig': {
        'active': 'true',
        'expectedEndAt': '2026-07-02T10:00:00+07:00',
        'retryAfterSeconds': '90',
      },
    });

    expect(bootstrap.siteName, 'ร้านค้าพาร์ทเนอร์');
    expect(bootstrap.supportPhone, '021111111');
    expect(bootstrap.privacyContent, 'privacy camel');
    expect(bootstrap.privacyPolicyUrl, 'https://partner.example.com/privacy');
    expect(
      bootstrap.accountDeletionUrl,
      'https://partner.example.com/delete-account',
    );
    expect(bootstrap.realtime.configured, isTrue);
    expect(bootstrap.realtime.url, 'https://realtime.partner.example.com');
    expect(bootstrap.realtime.key, 'partner-realtime-key');
    expect(bootstrap.realtime.authEndpoint, '/customer/realtime/custom-auth');
    expect(bootstrap.realtime.protocol, 8);
    expect(bootstrap.realtime.client, 'partner-flutter');
    expect(bootstrap.screenSecurity.androidFlagSecure, isFalse);
    expect(bootstrap.screenSecurity.androidProtectRecentAppPreview, isTrue);
    expect(bootstrap.screenSecurity.iosScreenshotPolicy, 'overlay_only');
    expect(bootstrap.screenSecurity.iosScreenCaptureOverlay, isFalse);
    expect(bootstrap.screenSecurity.iosExitApp, isTrue);
    expect(bootstrap.screenSecurity.webSensitiveScreenMode, 'strict');
    expect(bootstrap.screenSecurity.webWatermarkEnabled, isTrue);
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/reward-claims/claim_1'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/tenant-claims/claim_1'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/vip-secure/report/2026'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/vip-secure'),
      isFalse,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/purchase-history/ord_1'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/wallet-secure/123'),
      isTrue,
    );
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(bootstrap, 'web'),
      isTrue,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'android'),
      isTrue,
    );
    expect(bootstrap.featureFlags.enabled('native_biometric_unlock'), isFalse);
    expect(bootstrap.maintenance.active, isTrue);
    expect(bootstrap.maintenance.mode, 'checkout_payment_only');
    expect(bootstrap.maintenance.retryAfterSeconds, 90);
    expect(bootstrap.maintenance.allowedRoutes, ['/terms']);
    expect(
      bootstrap.maintenance.blocksRoute('/checkout/pending/order_1'),
      isTrue,
    );
    expect(bootstrap.maintenance.blocksRoute('/my-wallet'), isFalse);
    expect(
      bootstrap.maintenance.blocksRoute('/profile/reward-bank/edit'),
      isTrue,
    );
  });

  test('mobile bootstrap accepts flat screen security policy aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'features': {'screen_security_native': true},
      'screenSecurity': {
        'protectRecentAppPreview': 'true',
        'sensitiveRoutes': ['/wallet-secure/:id'],
      },
      'mobileConfig': {
        'flagSecure': 'false',
        'screenshotPolicy': 'overlay_only',
        'screenCaptureOverlay': 'false',
        'iosExitApp': 'true',
        'sensitiveScreenMode': 'strict',
        'watermarkEnabled': 'true',
        'features': {'native_biometric_unlock': false},
      },
    });

    expect(bootstrap.screenSecurity.androidFlagSecure, isFalse);
    expect(bootstrap.screenSecurity.androidProtectRecentAppPreview, isTrue);
    expect(bootstrap.screenSecurity.iosScreenshotPolicy, 'overlay_only');
    expect(bootstrap.screenSecurity.iosScreenCaptureOverlay, isFalse);
    expect(bootstrap.screenSecurity.iosExitApp, isTrue);
    expect(bootstrap.screenSecurity.webSensitiveScreenMode, 'strict');
    expect(bootstrap.screenSecurity.webWatermarkEnabled, isTrue);
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/wallet-secure/123'),
      isTrue,
    );
    expect(bootstrap.featureFlags.enabled('screen_security_native'), isTrue);
    expect(bootstrap.featureFlags.enabled('native_biometric_unlock'), isFalse);
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'android'),
      isTrue,
    );
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(bootstrap, 'web'),
      isTrue,
    );
  });

  test('mobile bootstrap normalizes web privacy mode aliases', () {
    final coverOnly = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'web': {
            'sensitive_screen_mode': 'privacy-cover',
            'watermark_enabled': false,
          },
        },
      },
    });
    final watermarkOnly = MobileBootstrap.fromJson({
      'screenSecurity': {
        'webSensitiveScreenMode': 'watermark-only',
        'webWatermarkEnabled': false,
      },
    });
    final disabled = MobileBootstrap.fromJson({
      'mobileConfig': {
        'webSensitiveScreenMode': 'DISABLE',
        'webWatermarkEnabled': true,
      },
    });
    final enabledWithoutWatermark = MobileBootstrap.fromJson({
      'screenSecurity': {
        'web': {
          'sensitiveScreenMode': 'enabled',
          'watermarkEnabled': false,
        },
      },
    });

    expect(coverOnly.screenSecurity.webSensitiveScreenMode, 'limited');
    expect(normalizeWebPrivacyMode('report-only'), 'limited');
    expect(normalizeWebPrivacyMode('true'), 'limited');
    expect(normalizeWebPrivacyMode('screen-protection'), 'limited');
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(coverOnly, 'web'),
      isTrue,
    );
    expect(
      webPrivacyModeShowsWatermark(
        coverOnly.screenSecurity.webSensitiveScreenMode,
        watermarkEnabled: coverOnly.screenSecurity.webWatermarkEnabled,
      ),
      isFalse,
    );
    expect(
      webPrivacyModeShowsLifecycleCover(
        coverOnly.screenSecurity.webSensitiveScreenMode,
      ),
      isTrue,
    );
    expect(watermarkOnly.screenSecurity.webSensitiveScreenMode, 'watermark');
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(watermarkOnly, 'web'),
      isTrue,
    );
    expect(
      webPrivacyModeShowsWatermark(
        watermarkOnly.screenSecurity.webSensitiveScreenMode,
        watermarkEnabled: watermarkOnly.screenSecurity.webWatermarkEnabled,
      ),
      isTrue,
    );
    expect(
      webPrivacyModeShowsLifecycleCover(
        watermarkOnly.screenSecurity.webSensitiveScreenMode,
      ),
      isFalse,
    );
    expect(disabled.screenSecurity.webSensitiveScreenMode, 'none');
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(disabled, 'web'),
      isFalse,
    );
    expect(
      enabledWithoutWatermark.screenSecurity.webSensitiveScreenMode,
      'limited',
    );
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(enabledWithoutWatermark, 'web'),
      isTrue,
    );
    expect(
      webPrivacyModeShowsWatermark(
        enabledWithoutWatermark.screenSecurity.webSensitiveScreenMode,
        watermarkEnabled:
            enabledWithoutWatermark.screenSecurity.webWatermarkEnabled,
      ),
      isFalse,
    );
    expect(
      webPrivacyModeShowsLifecycleCover(
        enabledWithoutWatermark.screenSecurity.webSensitiveScreenMode,
      ),
      isTrue,
    );
  });

  test('mobile bootstrap accepts store-readiness legal aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'displayName': 'Partner Legal',
        'supportPhone': '021234567',
      },
      'mobileConfig': {
        'storeReadiness': {
          'termsOfService': {'content': 'runtime terms'},
          'privacyPolicy': {
            'body': 'runtime privacy',
            'policyUrl': 'https://partner.example.com/privacy-policy',
          },
          'dataDeletion': {
            'requestUrl': 'https://partner.example.com/account/delete',
          },
        },
      },
    });

    expect(bootstrap.termsContent, 'runtime terms');
    expect(bootstrap.privacyContent, 'runtime privacy');
    expect(
      bootstrap.privacyPolicyUrl,
      'https://partner.example.com/privacy-policy',
    );
    expect(
      bootstrap.accountDeletionUrl,
      'https://partner.example.com/account/delete',
    );
  });

  test('mobile bootstrap accepts BO legal links and contact channel rows', () {
    final bootstrap = MobileBootstrap.fromJson({
      'legalConfig': {
        'terms': {'html': '<p>runtime terms html</p>'},
        'privacy': {'markdown': 'runtime privacy markdown'},
        'links': [
          {
            'rel': 'privacy-policy',
            'href': 'https://partner.example.com/legal/privacy',
          },
          {
            'type': 'accountDeletion',
            'targetUrl': 'https://partner.example.com/legal/delete-account',
          },
        ],
      },
      'supportConfig': {
        'channels': [
          {'type': 'line', 'value': '@partner'},
          {'type': 'phone', 'value': '023333333'},
          {
            'channel': 'supportEmail',
            'address': 'support+legal@example.test',
          },
          {
            'type': 'supportUrl',
            'value': 'https://partner.example.com/support',
          },
        ],
      },
    });

    expect(bootstrap.termsContent, '<p>runtime terms html</p>');
    expect(bootstrap.privacyContent, 'runtime privacy markdown');
    expect(
      bootstrap.privacyPolicyUrl,
      'https://partner.example.com/legal/privacy',
    );
    expect(
      bootstrap.accountDeletionUrl,
      'https://partner.example.com/legal/delete-account',
    );
    expect(bootstrap.supportPhone, '023333333');
    expect(bootstrap.supportEmail, 'support+legal@example.test');
    expect(bootstrap.supportUrl, 'https://partner.example.com/support');
  });

  test('mobile bootstrap accepts site store-listing compliance aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'storeListing': {
          'legal': {
            'links': [
              {
                'rel': 'appStorePrivacyPolicy',
                'publicUrl': 'https://partner.example.com/app/privacy',
              },
              {
                'rel': 'storeAccountDeletionUrl',
                'href': 'https://partner.example.com/app/delete-account',
              },
            ],
          },
          'developerContact': {
            'channels': [
              {
                'kind': 'customerServicePhone',
                'displayValue': '029999999',
              },
              {
                'kind': 'developerEmail',
                'address': 'store-support@example.test',
              },
              {
                'rel': 'storeListingSupport',
                'publicUrl': 'https://partner.example.com/app/support',
              },
            ],
          },
        },
      },
    });

    expect(
      bootstrap.privacyPolicyUrl,
      'https://partner.example.com/app/privacy',
    );
    expect(
      bootstrap.accountDeletionUrl,
      'https://partner.example.com/app/delete-account',
    );
    expect(bootstrap.supportPhone, '029999999');
    expect(bootstrap.supportEmail, 'store-support@example.test');
    expect(bootstrap.supportUrl, 'https://partner.example.com/app/support');
  });

  test('mobile bootstrap falls back to top-level LINE config', () {
    final bootstrap = MobileBootstrap.fromJson({
      'line': {
        'liff_id': '9876543210-ZyXwVu',
        'liff_enabled': true,
      },
      'mobile': <String, Object?>{},
    });

    expect(bootstrap.line.configured, isTrue);
    expect(bootstrap.line.liffId, '9876543210-ZyXwVu');
  });

  test('mobile bootstrap normalizes supported social auth providers', () {
    final bootstrap = MobileBootstrap.fromJson({
      'mobile': {
        'auth_providers': [
          {'provider': 'line_oauth', 'enabled': true},
          {'provider': 'google_oauth2', 'enabled': true, 'label': ''},
          {'provider': 'apple_login', 'enabled': true},
          {'provider': 'facebook', 'enabled': true},
          {'provider': 'google', 'enabled': false},
        ],
      },
    });

    expect(
      bootstrap.authProviders.map((provider) => provider.provider),
      ['line', 'google', 'apple'],
    );
    expect(
      bootstrap.authProviders.map((provider) => provider.label),
      ['LINE', 'Google', 'Apple ID'],
    );
  });

  test('mobile biometric policy is native-only and platform-aware', () {
    final bootstrap = MobileBootstrap.fromJson({
      'mobile': {
        'biometric': {
          'enabled': true,
          'platforms': {
            'ios': ['face_id'],
            'android': ['biometric_prompt'],
            'web': [],
          },
        },
        'feature_flags': {'native_biometric_unlock': true},
      },
    });
    final disabled = MobileBootstrap.fromJson({
      'mobile': {
        'biometric': {'enabled': true},
        'feature_flags': {'native_biometric_unlock': false},
      },
    });
    final legacyNative = MobileBootstrap.fromJson({
      'mobile': {
        'biometric': {'enabled': true},
        'feature_flags': {'native_biometric_unlock': true},
      },
    });

    expect(currentCustomerPlatformKey(isWeb: true), 'web');
    expect(
      currentCustomerPlatformKey(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      'ios',
    );
    expect(mobileBiometricAllowedForPlatform(bootstrap, 'ios'), isTrue);
    expect(mobileBiometricAllowedForPlatform(bootstrap, 'android'), isTrue);
    expect(mobileBiometricAllowedForPlatform(bootstrap, 'web'), isFalse);
    expect(mobileBiometricAllowedForPlatform(bootstrap, 'macos'), isFalse);
    expect(mobileBiometricAllowedForPlatform(disabled, 'ios'), isFalse);
    expect(mobileBiometricAllowedForPlatform(legacyNative, 'android'), isTrue);
    expect(mobileBiometricAllowedForPlatform(legacyNative, 'web'), isFalse);
  });

  test('mobile screen security policy is native-only and platform-aware', () {
    final bootstrap = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'android': {
            'flag_secure': true,
            'protect_recent_app_preview': true,
          },
          'ios': {
            'screenshot_policy': 'lock_and_blank',
            'screen_capture_overlay': true,
          },
          'web': {'watermark_enabled': true},
        },
        'feature_flags': {'screen_security_native': true},
      },
    });
    final disabled = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'android': {'flag_secure': true},
          'ios': {'screen_capture_overlay': true},
        },
        'feature_flags': {'screen_security_native': false},
      },
    });
    final iosPolicyDisabled = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'ios': {
            'screenshot_policy': 'none',
            'screen_capture_overlay': false,
          },
        },
        'feature_flags': {'screen_security_native': true},
      },
    });
    final iosOverlayOnly = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'ios': {
            'screenshot_policy': 'overlay_only',
            'screen_capture_overlay': true,
            'exit_app': false,
          },
        },
        'feature_flags': {'screen_security_native': true},
      },
    });
    final iosExitPolicy = MobileBootstrap.fromJson({
      'mobile': {
        'screen_security': {
          'ios': {
            'screenshot_policy': 'overlay_only',
            'screen_capture_overlay': true,
            'exit_app': true,
          },
        },
        'feature_flags': {'screen_security_native': true},
      },
    });

    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'android'),
      isTrue,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'ios'),
      isTrue,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'web'),
      isFalse,
    );
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(bootstrap, 'web'),
      isTrue,
    );
    expect(
      mobileWebPrivacyGuardAllowedForPlatform(bootstrap, 'android'),
      isFalse,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(bootstrap, 'macos'),
      isFalse,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(disabled, 'android'),
      isFalse,
    );
    expect(
      mobileNativeScreenSecurityAllowedForPlatform(iosPolicyDisabled, 'ios'),
      isFalse,
    );
    expect(
      mobileNativeScreenSecurityLocksOnCapture(bootstrap.screenSecurity, 'ios'),
      isTrue,
    );
    expect(
      mobileNativeScreenSecurityLocksOnCapture(
        iosOverlayOnly.screenSecurity,
        'ios',
      ),
      isFalse,
    );
    expect(
      mobileNativeScreenSecurityLocksOnCapture(
        iosExitPolicy.screenSecurity,
        'ios',
      ),
      isTrue,
    );
    expect(
      mobileNativeScreenSecurityLocksOnCapture(bootstrap.screenSecurity, 'web'),
      isFalse,
    );
    expect(mobileNativeScreenSecurityFallbackForPlatform('android'), isTrue);
    expect(mobileNativeScreenSecurityFallbackForPlatform('ios'), isTrue);
    expect(mobileNativeScreenSecurityFallbackForPlatform('web'), isFalse);
    expect(mobileWebPrivacyGuardFallbackForPlatform('web'), isTrue);
    expect(mobileWebPrivacyGuardFallbackForPlatform('ios'), isFalse);
  });

  test('moneyToDisplayNumber converts minor unit object to baht', () {
    expect(moneyToDisplayNumber({'amount': 12345, 'currency': 'THB'}), 123.45);
    expect(moneyToDisplayNumber('500.50'), 500.50);
  });

  test('baht formatter supports localized currency suffixes', () {
    final previousLocale = Intl.defaultLocale;
    try {
      Intl.defaultLocale = 'th_TH';
      expect(formatBaht(1234), '1,234.00 บาท');

      Intl.defaultLocale = 'en_US';
      expect(formatBaht(1234), '1,234.00 THB');
      expect(formatSignedBaht(-50), '-50.00 THB');

      expect(
        formatBahtForLocale(1234, localeTag: 'en-US', unit: 'THB'),
        '1,234.00 THB',
      );
      expect(
        formatSignedBahtForLocale(-50, localeTag: 'en-US', unit: 'THB'),
        '-50.00 THB',
      );
    } finally {
      Intl.defaultLocale = previousLocale;
    }
  });

  test('wallet summary picks primary wallet balance', () {
    final summary = WalletSummary(
      wallets: const [
        CustomerWallet(id: '2', name: 'Bonus', type: 'bonus', balance: 50),
        CustomerWallet(
          id: '1',
          name: 'G Wallet',
          type: 'primary',
          balance: 100,
        ),
      ],
      ledger: const [],
    );

    expect(summary.balance, 100);
  });

  test('wallet summary honors runtime primary wallet flags', () {
    final summary = WalletSummary(
      wallets: [
        CustomerWallet.fromJson({
          'id': 'wallet_bonus',
          'name': 'Bonus',
          'type': 'bonus',
          'balance': {'amount': 5000, 'currency': 'THB'},
        }),
        CustomerWallet.fromJson({
          'id': 'wallet_runtime_primary',
          'name': 'G Wallet',
          'walletType': 'g_wallet',
          'is_primary': true,
          'availableBalance': {'amount': 250000, 'currency': 'THB'},
        }),
      ],
      ledger: const [],
    );

    expect(summary.primaryWallet?.id, 'wallet_runtime_primary');
    expect(summary.primaryWallet?.isPrimary, isTrue);
    expect(summary.balance, 2500);
  });

  test('wallet parsers accept wrapped and camelCase wallet payloads', () {
    final wallet = CustomerWallet.fromJson({
      'primaryWallet': {
        'walletId': 'wallet_camel',
        'displayName': 'Runtime Wallet',
        'walletType': 'Primary',
        'availableBalance': {'amount': 123450, 'currency': 'THB'},
      },
    });
    final debit = WalletLedgerEntry.fromJson({
      'transaction': {
        'transactionId': 'ledger_camel',
        'entryType': 'debit',
        'referenceType': 'order',
        'referenceId': 'ord_camel',
        'description': 'ชำระค่าสลากดิจิทัล',
        'transactionAmount': {'amount': 8000, 'currency': 'THB'},
        'balanceAfter': {'amount': 115450, 'currency': 'THB'},
        'postedAt': '2026-07-01T11:30:00+07:00',
      },
    });
    final credit = WalletLedgerEntry.fromJson({
      'ledger': {
        'ledgerId': 'ledger_credit',
        'transactionType': 'credit',
        'sourceType': 'topup',
        'refId': 'top_camel',
        'memo': 'เติมเงินสำเร็จ',
        'amount': {'amount': 50000, 'currency': 'THB'},
        'runningBalance': {'amount': 165450, 'currency': 'THB'},
        'transactionAt': '2026-07-01T12:00:00+07:00',
      },
    });
    final summary = WalletSummary(wallets: [wallet], ledger: [debit, credit]);

    expect(wallet.id, 'wallet_camel');
    expect(wallet.name, 'Runtime Wallet');
    expect(wallet.type, 'Primary');
    expect(wallet.balance, 1234.5);
    expect(summary.primaryWallet?.id, 'wallet_camel');
    expect(summary.balance, 1234.5);
    expect(debit.id, 'ledger_camel');
    expect(debit.entryType, 'debit');
    expect(debit.referenceType, 'order');
    expect(debit.referenceId, 'ord_camel');
    expect(debit.reason, 'ชำระค่าสลากดิจิทัล');
    expect(debit.amount, -80);
    expect(debit.balanceAfter, 1154.5);
    expect(debit.createdAt, '2026-07-01T11:30:00+07:00');
    expect(debit.isDebit, isTrue);
    expect(credit.id, 'ledger_credit');
    expect(credit.referenceType, 'topup');
    expect(credit.referenceId, 'top_camel');
    expect(credit.amount, 500);
    expect(credit.balanceAfter, 1654.5);
    expect(credit.createdAt, '2026-07-01T12:00:00+07:00');
    expect(credit.isCredit, isTrue);
  });

  test('wallet parser leaves a missing runtime name empty', () {
    final wallet = CustomerWallet.fromJson({
      'id': 'wallet_without_name',
      'type': 'primary',
      'balance': {'amount': 2500, 'currency': 'THB'},
    });

    expect(wallet.name, isEmpty);
  });

  test('wallet parsers preserve recursive wrapper context', () {
    final wallet = CustomerWallet.fromJson({
      'walletName': 'Runtime Wrapper Wallet',
      'data': {
        'resource': {
          'primaryWallet': {
            'walletId': 'wallet_recursive',
            'walletType': 'primary',
            'availableBalance': {'amount': 987650, 'currency': 'THB'},
          },
        },
      },
    });
    final ledger = WalletLedgerEntry.fromJson({
      'memo': 'ชำระค่าสลากจาก wrapper',
      'data': {
        'resource': {
          'transaction': {
            'transactionId': 'ledger_recursive',
            'transactionType': 'debit',
            'referenceType': 'order',
            'referenceId': 'ord_recursive',
            'transactionAmount': {'amount': 16000, 'currency': 'THB'},
            'runningBalance': {'amount': 971650, 'currency': 'THB'},
            'transactionAt': '2026-07-01T13:00:00+07:00',
          },
        },
      },
    });

    expect(wallet.id, 'wallet_recursive');
    expect(wallet.name, 'Runtime Wrapper Wallet');
    expect(wallet.type, 'primary');
    expect(wallet.balance, 9876.5);
    expect(ledger.id, 'ledger_recursive');
    expect(ledger.referenceType, 'order');
    expect(ledger.referenceId, 'ord_recursive');
    expect(ledger.reason, 'ชำระค่าสลากจาก wrapper');
    expect(ledger.amount, -160);
    expect(ledger.balanceAfter, 9716.5);
    expect(ledger.createdAt, '2026-07-01T13:00:00+07:00');
  });

  test('wallet ledger parser normalizes production debit and credit aliases',
      () {
    final checkoutDebit = WalletLedgerEntry.fromJson({
      'transactionId': 'ledger_checkout',
      'referenceType': 'checkout_order',
      'transactionAmount': {'amount': 24000, 'currency': 'THB'},
      'balanceAfter': {'amount': 76000, 'currency': 'THB'},
    });
    final explicitDebit = WalletLedgerEntry.fromJson({
      'ledgerId': 'ledger_outflow',
      'flowType': 'outflow',
      'debitAmount': {'amount': 12000, 'currency': 'THB'},
      'runningBalance': {'amount': 64000, 'currency': 'THB'},
    });
    final explicitCredit = WalletLedgerEntry.fromJson({
      'ledgerId': 'ledger_inflow',
      'flow': 'wallet_adjust',
      'creditAmount': {'amount': 35000, 'currency': 'THB'},
      'runningBalance': {'amount': 99000, 'currency': 'THB'},
    });
    final signedAmount = WalletLedgerEntry.fromJson({
      'ledgerId': 'ledger_signed',
      'referenceType': 'topup',
      'signedAmount': {'amount': -10000, 'currency': 'THB'},
      'runningBalance': {'amount': 89000, 'currency': 'THB'},
    });

    expect(checkoutDebit.amount, -240);
    expect(checkoutDebit.isDebit, isTrue);
    expect(explicitDebit.amount, -120);
    expect(explicitCredit.amount, 350);
    expect(explicitCredit.isCredit, isTrue);
    expect(signedAmount.amount, -100);
  });

  test('wallet parsers unwrap object scalar rows', () {
    final wallet = CustomerWallet.fromJson({
      'primaryWallet': {
        'walletId': {'value': 'wallet_object'},
        'displayName': {'value': 'Object Wallet'},
        'walletType': {'code': 'g_wallet'},
        'primary': {'value': 'on'},
        'availableBalance': {
          'value': {'amount': 123450, 'currency': 'THB'},
        },
      },
    });
    final ledger = WalletLedgerEntry.fromJson({
      'transaction': {
        'transactionId': {'value': 'ledger_object'},
        'flowType': {'key': 'out-flow'},
        'transactionAmount': {
          'value': {'amount': 8000, 'currency': 'THB'},
        },
        'balanceAfter': {
          'value': {'amount': 115450, 'currency': 'THB'},
        },
        'postedAt': {'value': '2026-07-01T11:30:00+07:00'},
        'details': {
          'description': {'value': 'ชำระค่าสลากจาก object row'},
          'reference': {
            'type': {'code': 'order'},
            'id': {'value': 'ORD-OBJECT'},
          },
        },
      },
    });

    expect(wallet.id, 'wallet_object');
    expect(wallet.name, 'Object Wallet');
    expect(wallet.type, 'g_wallet');
    expect(wallet.isPrimary, isTrue);
    expect(wallet.balance, 1234.5);
    expect(ledger.id, 'ledger_object');
    expect(ledger.entryType, 'out-flow');
    expect(ledger.referenceType, 'order');
    expect(ledger.referenceId, 'ORD-OBJECT');
    expect(ledger.reason, 'ชำระค่าสลากจาก object row');
    expect(ledger.amount, -80);
    expect(ledger.balanceAfter, 1154.5);
    expect(ledger.createdAt, '2026-07-01T11:30:00+07:00');
  });

  test('activity model maps lucky board remaining numbers', () {
    final activity = ActivityItem.fromJson({
      'id': 1,
      'name': 'ทายเลข 2 ตัว',
      'slug': 'luck',
      'type': 'lucky_board',
      'number_board': {'total_count': 100, 'reserved_count': 7},
    });

    expect(activity.type, 'lucky_board');
    expect(activity.remainingNumbers, 93);
  });

  test('activity model selects typed number board using prediction config', () {
    final activity = ActivityItem.fromJson({
      'id': 'act_typed_board',
      'name': 'ทายเลขหลายรูปแบบ',
      'slug': 'typed-board',
      'type': 'lucky_board',
      'config': {
        'predictionTypes': {
          'first_prize_last2': false,
          'first_prize_last3': true,
          'last2': true,
        },
      },
      'numberBoard': {
        'types': {
          'first_prize_last2': {
            'totalCount': 100,
            'reservedNumbers': ['07'],
            'remainingCount': 93,
          },
          'first_prize_last3': {
            'totalCount': 1000,
            'reservedNumbers': [7, '008'],
            'remainingCount': 998,
          },
          'last2': {
            'totalCount': 100,
            'reservedNumbers': ['55'],
            'remainingCount': 99,
          },
        },
      },
      'activityEntries': [
        {
          'id': 'entry_typed_1',
          'predictionType': 'first_prize_last3',
          'selectedNumber': 7,
          'status': 'submitted',
        },
        {
          'id': 'entry_typed_2',
          'predictionType': 'first_prize_last3',
          'selectedNumber': '009',
          'status': 'cancelled',
        },
      ],
    });

    expect(activity.config.enabledPredictionTypes, [
      'first_prize_last3',
      'last2',
    ]);
    expect(activity.numberBoard.predictionType, 'first_prize_last3');
    expect(activity.numberBoard.digits, 3);
    expect(activity.numberBoard.totalCount, 1000);
    expect(activity.numberBoard.remainingCount, 998);
    expect(activity.numberBoard.isReserved('007'), isTrue);
    expect(activity.numberBoard.isReserved('07'), isFalse);
    expect(activity.entries.first.selectedNumber, '007');
    expect(activity.entries.first.isCancelled, isFalse);
    expect(activity.entries.last.selectedNumber, '009');
    expect(activity.entries.last.isCancelled, isTrue);
  });

  test('activity list page maps history metadata and game options', () {
    final page = ActivityListPage.fromJson({
      'data': [
        {
          'id': 'act_1',
          'name': 'งวดเก่า',
          'slug': 'old-draw',
          'type': 'cashback',
        },
      ],
      'meta': {
        'has_history': true,
        'has_more': true,
        'next_cursor': 'activity_cursor_2',
        'selected_game_id': 'game_2',
        'games': [
          {'id': 'game_2', 'label': 'งวด 16 มิ.ย. 2569'},
          {'id': 'game_1', 'name': 'งวด 1 มิ.ย. 2569'},
        ],
      },
    });

    expect(page.items.single.slug, 'old-draw');
    expect(page.meta.hasHistory, isTrue);
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.nextCursor, 'activity_cursor_2');
    expect(page.meta.selectedGameId, 'game_2');
    expect(page.meta.games.map((game) => game.label), [
      'งวด 16 มิ.ย. 2569',
      'งวด 1 มิ.ย. 2569',
    ]);
  });

  test('activity list page maps nested data and meta payload shape', () {
    final page = ActivityListPage.fromJson({
      'data': {
        'data': [
          {'id': 'act_1', 'slug': 'nested', 'type': 'lucky_board'},
        ],
        'meta': {
          'selected_game_id': 'game_nested',
          'games': [
            {'id': 'game_nested', 'code': 'G-001'},
          ],
        },
      },
    });

    expect(page.items.single.slug, 'nested');
    expect(page.meta.selectedGameId, 'game_nested');
    expect(page.meta.games.single.label, 'G-001');
  });

  test('activity list page maps result activities and camelCase metadata', () {
    final page = ActivityListPage.fromJson(
      {
        'result': {
          'activities': [
            {
              'activityId': 'act_camel',
              'title': 'กิจกรรม Camel',
              'slug': 'camel',
              'activityType': 'lucky_board',
              'conditionText': 'เงื่อนไข runtime',
              'imageThumbUrl': '/storage/camel.webp',
              'rights': {
                'remainingCount': 2,
                'earnedCount': 3,
                'usedCount': 1,
                'ticketCount': 30,
              },
              'numberBoard': {
                'predictionType': 'last2',
                'totalCount': 100,
                'reservedNumbers': ['07'],
                'remainingCount': 98,
              },
              'cashbackProgress': {
                'isEligible': true,
                'estimatedAmount': {'amount': 5000, 'currency': 'THB'},
              },
              'resultSummary': {
                'status': 'announced',
                'predictionType': 'last2',
                'winningNumber': '42',
                'winnerCount': 1,
                'awardTotal': {'amount': 99000, 'currency': 'THB'},
                'customer': {
                  'status': 'won',
                  'winningNumbers': ['42'],
                  'awardAmount': {'amount': 99000, 'currency': 'THB'},
                },
              },
            },
          ],
          'meta': {
            'hasHistory': true,
            'hasMore': true,
            'nextCursor': 'cursor_camel',
            'selectedGameId': 'game_camel',
            'gameOptions': [
              {'gameId': 'game_camel', 'drawLabel': 'งวด Camel'},
            ],
          },
        },
      },
      resolveAssetUrl: (value) => 'asset:$value',
    );

    final activity = page.items.single;
    expect(activity.id, 'act_camel');
    expect(activity.name, 'กิจกรรม Camel');
    expect(activity.imageUrl, 'asset:/storage/camel.webp');
    expect(activity.conditionText, 'เงื่อนไข runtime');
    expect(activity.hasRight, isTrue);
    expect(activity.rights.remainingCount, 2);
    expect(activity.numberBoard.isReserved('07'), isTrue);
    expect(activity.cashbackProgress.estimatedAmount, 50);
    expect(activity.resultSummary?.winningNumbers, ['42']);
    expect(activity.resultSummary?.customerAwardAmount, 990);
    expect(page.meta.hasHistory, isTrue);
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.nextCursor, 'cursor_camel');
    expect(page.meta.selectedGameId, 'game_camel');
    expect(page.meta.games.single.id, 'game_camel');
    expect(page.meta.games.single.label, 'งวด Camel');
  });

  test('activity model preserves cashback runtime config for public detail',
      () {
    final activity = ActivityItem.fromJson({
      'id': 'act_cashback_config',
      'name': 'เงินคืนทุกงวด',
      'slug': 'cashback-config',
      'type': 'cashback',
      'config': {
        'cashbackType': 'fixed',
        'cashbackPercentBps': 0,
        'fixedAmount': {'amount': 12000, 'currency': 'THB'},
        'minimumType': 'amount',
        'minTicketCount': 0,
        'minPurchaseAmount': {'amount': 150000, 'currency': 'THB'},
      },
    });

    expect(activity.config.cashbackType, 'fixed');
    expect(activity.config.cashbackPercentBps, 0);
    expect(activity.config.fixedAmount, 120);
    expect(activity.config.minimumType, 'amount');
    expect(activity.config.minTicketCount, 0);
    expect(activity.config.minPurchaseAmount, 1500);
  });

  test('activity list page preserves recursive resource wrapper context', () {
    final page = ActivityListPage.fromJson(
      {
        'meta': {
          'hasHistory': true,
          'selectedGameId': 'game_outer',
        },
        'data': {
          'resource': {
            'activityPage': {
              'activityItems': [
                {
                  'activity': {
                    'activityId': 'act_recursive',
                    'title': 'กิจกรรม Recursive',
                    'slug': 'recursive',
                    'activityType': 'cashback',
                    'imageThumbUrl': '/storage/recursive.webp',
                    'cashbackProgress': {
                      'isEligible': true,
                      'estimatedAmount': {
                        'amount': 12300,
                        'currency': 'THB',
                      },
                    },
                  },
                },
              ],
              'meta': {
                'hasMore': true,
                'nextCursor': 'activity_recursive_cursor',
                'gameOptions': [
                  {'gameId': 'game_outer', 'drawLabel': 'งวด Recursive'},
                ],
              },
            },
          },
        },
      },
      resolveAssetUrl: (value) => 'asset:$value',
    );

    final activity = page.items.single;
    expect(activity.id, 'act_recursive');
    expect(activity.name, 'กิจกรรม Recursive');
    expect(activity.imageUrl, 'asset:/storage/recursive.webp');
    expect(activity.hasRight, isTrue);
    expect(activity.cashbackProgress.estimatedAmount, 123);
    expect(page.meta.hasHistory, isTrue);
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.nextCursor, 'activity_recursive_cursor');
    expect(page.meta.selectedGameId, 'game_outer');
    expect(page.meta.games.single.label, 'งวด Recursive');
  });

  test('activity pages accept production page wrapper aliases', () {
    final listPage = ActivityListPage.fromJson(
      {
        'meta': {'hasHistory': true},
        'data': {
          'resource': {
            'activitiesPage': {
              'activities': [
                {
                  'activity': {
                    'activityId': 'act_page_alias',
                    'title': 'กิจกรรม Page Alias',
                    'slug': 'page-alias',
                    'activityType': 'lucky_board',
                    'imageThumbUrl': '/storage/page-alias.webp',
                    'remainingRights': '2',
                  },
                },
              ],
              'pagination': {
                'hasMore': true,
                'nextCursor': 'activity_page_alias_cursor',
                'selectedGameId': 'game_page_alias',
                'gameOptions': [
                  {'gameId': 'game_page_alias', 'drawLabel': 'งวด Page'},
                ],
              },
            },
          },
        },
      },
      resolveAssetUrl: (value) => 'asset:$value',
    );
    final awardPage = ActivityAwardPage.fromJson({
      'data': {
        'resource': {
          'activityAwardsPage': {
            'activityAwards': [
              {
                'activityAward': {
                  'awardId': 'awa_page_alias',
                  'activityId': 'act_page_alias',
                  'activityName': 'กิจกรรม Page Alias',
                  'awardType': 'cashback',
                  'awardAmount': {'amount': 45000, 'currency': 'THB'},
                  'claimStatus': 'claim_submitted',
                  'claimId': 'acl_page_alias',
                },
              },
            ],
            'pagination': {
              'hasMore': true,
              'nextCursor': 'award_page_alias_cursor',
            },
          },
        },
      },
    });

    final activity = listPage.items.single;
    expect(activity.id, 'act_page_alias');
    expect(activity.name, 'กิจกรรม Page Alias');
    expect(activity.imageUrl, 'asset:/storage/page-alias.webp');
    expect(activity.rights.remainingCount, 2);
    expect(listPage.meta.hasHistory, isTrue);
    expect(listPage.meta.hasMore, isTrue);
    expect(listPage.meta.nextCursor, 'activity_page_alias_cursor');
    expect(listPage.meta.selectedGameId, 'game_page_alias');
    expect(listPage.meta.games.single.label, 'งวด Page');

    final award = awardPage.items.single;
    expect(award.id, 'awa_page_alias');
    expect(award.activityId, 'act_page_alias');
    expect(award.activityName, 'กิจกรรม Page Alias');
    expect(award.amount, 450);
    expect(award.status, 'submitted');
    expect(award.claimId, 'acl_page_alias');
    expect(awardPage.hasMore, isTrue);
    expect(awardPage.nextCursor, 'award_page_alias_cursor');
  });

  test('activity model maps rights entries reserved numbers and result', () {
    final activity = ActivityItem.fromJson({
      'id': 'act_1',
      'name': 'ทายเลข 2 ตัว',
      'slug': 'luck',
      'type': 'lucky_board',
      'number_board': {
        'prediction_type': 'last2',
        'digits': 2,
        'total_count': 100,
        'reserved_count': 2,
        'remaining_count': 98,
        'reserved_numbers': ['01', '09'],
      },
      'rights': {
        'earned_count': '3',
        'used_count': 1,
        'remaining_count': 2,
        'ticket_count': 30,
        'consumed_ticket_count': 10,
        'entry_closed': false,
      },
      'entries': [
        {'id': 'entry_1', 'prediction_type': 'last2', 'selected_number': '09'},
      ],
      'result_summary': {
        'status': 'announced',
        'prediction_type': 'last2',
        'winning_number': '09',
        'winner_count': 4,
        'award_total': {'amount': 120000, 'currency': 'THB'},
        'customer': {
          'status': 'won',
          'winning_numbers': ['09'],
          'award_amount': {'amount': 30000, 'currency': 'THB'},
        },
      },
    });

    expect(activity.rights.remainingCount, 2);
    expect(activity.hasRight, isTrue);
    expect(activity.entries.single.selectedNumber, '09');
    expect(activity.numberBoard.isReserved('01'), isTrue);
    expect(activity.numberBoard.predictionType, 'last2');
    expect(activity.resultSummary?.winningNumbers, ['09']);
    expect(activity.resultSummary?.customerWon, isTrue);
    expect(activity.resultSummary?.customerAwardAmount, 300);
  });

  test('activity result summary maps Nuxt winning number arrays', () {
    final activity = ActivityItem.fromJson({
      'id': 'act_result_array',
      'type': 'lucky_board',
      'result_summary': {
        'status': 'announced',
        'prediction_type': 'first_prize_last3',
        'winning_numbers': [7, '108'],
        'winner_count': 2,
        'customer': {
          'status': 'won',
          'winning_numbers': ['7'],
          'award_amount': {'amount': 250000, 'currency': 'THB'},
        },
      },
    });

    final summary = activity.resultSummary;
    expect(summary?.isAnnounced, isTrue);
    expect(summary?.winningNumber, '007');
    expect(summary?.winningNumbers, ['007', '108']);
    expect(summary?.customerWinningNumbers, ['007']);
    expect(summary?.customerWon, isTrue);
    expect(summary?.customerAwardAmount, 2500);
  });

  test('activity model maps root rights aliases and entry deadline', () {
    final activity = ActivityItem.fromJson({
      'activityId': 'act_deadline',
      'title': 'กิจกรรมใกล้ปิดรับ',
      'slug': 'deadline',
      'activityType': 'lucky_board',
      'remainingRights': '4',
      'earnedRights': '5',
      'usedRights': '1',
      'entryDeadlineAt': '2026-07-01T14:30:00+07:00',
      'entryClosed': true,
      'numberBoard': {'totalCount': 100, 'remainingCount': 80},
    });

    expect(activity.rights.remainingCount, 4);
    expect(activity.rights.earnedCount, 5);
    expect(activity.rights.usedCount, 1);
    expect(activity.rights.entryDeadlineAt, '2026-07-01T14:30:00+07:00');
    expect(activity.rights.entryClosed, isTrue);
  });

  test('activity award page maps claimable awards', () {
    final page = ActivityAwardPage.fromJson({
      'data': [
        {
          'id': 'awa_1',
          'activity_id': 'act_1',
          'activity_name': 'เงินคืน 5%',
          'type': 'cashback',
          'amount': {'amount': 4500, 'currency': 'THB'},
          'status': 'claimable',
        },
      ],
      'meta': {'has_more': false},
    });

    expect(page.items.single.isClaimable, isTrue);
    expect(page.items.single.type, 'cashback');
    expect(page.items.single.amount, 45);
  });

  test('activity award page maps result activityAwards and camelCase fields',
      () {
    final page = ActivityAwardPage.fromJson({
      'result': {
        'activityAwards': [
          {
            'awardId': 'awa_camel',
            'activityId': 'act_camel',
            'activityName': 'เงินคืน Camel',
            'awardType': 'cashback',
            'predictionType': 'last2',
            'awardAmount': {'amount': 4500, 'currency': 'THB'},
            'status': 'claimable',
            'claimId': 'claim_camel',
            'calculatedAt': '2026-07-01T12:00:00+07:00',
          },
        ],
        'meta': {'hasMore': true, 'nextCursor': 'award_cursor_2'},
      },
    });

    final award = page.items.single;
    expect(award.id, 'awa_camel');
    expect(award.activityId, 'act_camel');
    expect(award.activityName, 'เงินคืน Camel');
    expect(award.type, 'cashback');
    expect(award.predictionType, 'last2');
    expect(award.amount, 45);
    expect(award.claimId, 'claim_camel');
    expect(award.calculatedAt, '2026-07-01T12:00:00+07:00');
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'award_cursor_2');
  });

  test('activity award page preserves recursive resource wrapper context', () {
    final page = ActivityAwardPage.fromJson({
      'meta': {'hasMore': true},
      'data': {
        'resource': {
          'awardsPage': {
            'activityAwards': [
              {
                'activityAward': {
                  'awardId': 'awa_recursive',
                  'activityId': 'act_recursive',
                  'activityName': 'เงินคืน Recursive',
                  'awardType': 'cashback',
                  'awardAmount': {'amount': 9900, 'currency': 'THB'},
                  'status': 'claimable',
                },
              },
            ],
            'pagination': {'nextCursor': 'award_recursive_cursor'},
          },
        },
      },
    });

    final award = page.items.single;
    expect(award.id, 'awa_recursive');
    expect(award.activityId, 'act_recursive');
    expect(award.activityName, 'เงินคืน Recursive');
    expect(award.amount, 99);
    expect(award.isClaimable, isTrue);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'award_recursive_cursor');
  });

  test('activity award page normalizes claim status aliases', () {
    final page = ActivityAwardPage.fromJson({
      'result': {
        'activityAwards': [
          {
            'awardId': 'awa_claimable',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 100,
            'claimable': true,
          },
          {
            'awardId': 'awa_review',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 200,
            'presentationStatus': ' under_review ',
          },
          {
            'awardId': 'awa_paid',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 300,
            'claim_status': 'claim_paid',
          },
          {
            'awardId': 'awa_paid_out',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 350,
            'claimStatus': 'paid_out',
          },
          {
            'awardId': 'awa_nested_claim_paid',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 375,
            'claim': {
              'id': 'activity_claim_paid_nested',
              'claimStatus': 'claim_paid',
            },
          },
          {
            'awardId': 'awa_approved_paid',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 390,
            'status': 'approved',
            'claim': {
              'id': 'activity_claim_paid_evidence',
              'paidAt': '2026-07-01T12:00:00+07:00',
            },
          },
          {
            'awardId': 'awa_rejected',
            'activityId': 'act_1',
            'awardType': 'cashback',
            'awardAmount': 400,
            'claimStatus': 'declined',
          },
        ],
      },
    });

    final awards = page.items;
    expect(awards[0].status, 'claimable');
    expect(awards[0].isClaimable, isTrue);
    expect(awards[1].status, 'submitted');
    expect(awards[1].hasClaim, isTrue);
    expect(awards[2].status, 'paid');
    expect(awards[2].isPaid, isTrue);
    expect(awards[2].hasClaim, isTrue);
    expect(awards[3].status, 'paid');
    expect(awards[3].isPaid, isTrue);
    expect(awards[3].hasClaim, isTrue);
    expect(awards[4].status, 'paid');
    expect(awards[4].isPaid, isTrue);
    expect(awards[4].claimId, 'activity_claim_paid_nested');
    expect(awards[4].hasClaim, isTrue);
    expect(awards[5].status, 'paid');
    expect(awards[5].isPaid, isTrue);
    expect(awards[5].claimId, 'activity_claim_paid_evidence');
    expect(awards[5].hasClaim, isTrue);
    expect(awards[6].status, 'rejected');
    expect(awards[6].isRejected, isTrue);
    expect(awards[6].hasClaim, isFalse);
  });

  test('activity entry maps nested wrapper and camelCase fields', () {
    final entry = ActivityEntry.fromJson({
      'data': {
        'resource': {
          'entry': {
            'entryId': 'entry_camel',
            'predictionType': 'last2',
            'selectedNumber': '42',
            'status': 'submitted',
            'createdAt': '2026-07-01T10:00:00+07:00',
          },
        },
      },
    });

    expect(entry.id, 'entry_camel');
    expect(entry.predictionType, 'last2');
    expect(entry.selectedNumber, '42');
    expect(entry.status, 'submitted');
    expect(entry.createdAt, '2026-07-01T10:00:00+07:00');
  });

  test('current game parser keeps sale window fields for sale guards', () {
    final game = CurrentGame.fromJson({
      'id': 'game_1',
      'name': 'งวดวันที่ 1 ก.ค. 2569',
      'status': 'open',
      'draw_at': '2026-07-01T15:00:00+07:00',
      'sale_start_at': '2026-06-25T09:00:00+07:00',
      'close_at': '2026-07-01T14:30:00+07:00',
      'server_time': '2026-06-25T09:05:00+07:00',
    });

    expect(game.saleStartAt, '2026-06-25T09:00:00+07:00');
    expect(game.saleCloseAt, '2026-07-01T14:30:00+07:00');
    expect(game.serverTime, '2026-06-25T09:05:00+07:00');
  });

  test('current game parser accepts wrapped and camelCase sale window fields',
      () {
    final game = CurrentGame.fromJson({
      'data': {
        'currentGame': {
          'gameId': 'game_camel',
          'drawLabel': 'งวด Camel',
          'statusCode': 1,
          'drawAt': '2026-07-01T15:00:00+07:00',
          'saleStartAt': '2026-06-25T09:00:00+07:00',
          'saleCloseAt': '2026-07-01T14:30:00+07:00',
          'serverTime': '2026-06-25T09:05:00+07:00',
        },
      },
    });

    expect(game.id, 'game_camel');
    expect(game.name, 'งวด Camel');
    expect(game.status, '1');
    expect(game.drawAt, '2026-07-01T15:00:00+07:00');
    expect(game.saleStartAt, '2026-06-25T09:00:00+07:00');
    expect(game.saleCloseAt, '2026-07-01T14:30:00+07:00');
    expect(game.serverTime, '2026-06-25T09:05:00+07:00');
  });

  test('store parsers map affiliate stores and stock tickets', () {
    final stores = StorePage.fromJson({
      'data': [
        {'id': 'aff_1', 'name': 'ร้านพบโชค', 'code': 'PCHOKE'},
      ],
      'meta': {'next_cursor': 'aff_1', 'has_more': true},
    });
    final tickets = StoreLotteryPage.fromJson({
      'data': [
        {
          'id': 'vstock:game_1:273707:1',
          'token': 'stock-token',
          'local_stock_item_id': 'local-stock-1',
          'virtual_stock_ref': 'vstock-ref-1',
          'full_number': '273707',
          'store_name': 'ร้านพบโชค',
          'price': 80,
          'remaining_count': 5,
          'reservation_id': 'reservation_1',
        },
      ],
      'meta': {'game_id': 'game_1', 'has_more': false, 'bet_status': 0},
    });

    expect(stores.items.single.name, 'ร้านพบโชค');
    expect(stores.nextCursor, 'aff_1');
    expect(stores.hasMore, isTrue);
    expect(tickets.items.single.number, '273707');
    expect(tickets.items.single.id, 'vstock:game_1:273707:1');
    expect(tickets.items.single.localStockItemId, 'local-stock-1');
    expect(tickets.items.single.stockRef, 'vstock-ref-1');
    expect(tickets.items.single.reservationId, 'reservation_1');
    expect(tickets.items.single.isAvailable, isTrue);
    expect(tickets.canReserve, isFalse);
  });

  test('store list parser accepts legacy result stores and pagination', () {
    final stores = StorePage.fromJson({
      'result': {
        'stores': [
          {
            'store_id': 'store_legacy_1',
            'store_name': 'ร้านเก่าโชคดี',
            'code': 'OLDLUCK',
          },
          {
            'affiliate_id': 'aff_legacy_2',
            'display_name': 'ร้านตัวแทนโชคดี',
          },
        ],
        'pagination': {
          'next_cursor': 'store_cursor_2',
          'has_more': 1,
        },
      },
    });

    expect(stores.items.map((store) => store.id), [
      'store_legacy_1',
      'aff_legacy_2',
    ]);
    expect(stores.items.map((store) => store.name), [
      'ร้านเก่าโชคดี',
      'ร้านตัวแทนโชคดี',
    ]);
    expect(stores.items.first.code, 'OLDLUCK');
    expect(stores.nextCursor, 'store_cursor_2');
    expect(stores.hasMore, isTrue);

    final storeListAlias = StorePage.fromJson({
      'result': {
        'store_list': [
          {'id': 'store_alias_1', 'seller_name': 'ร้านนามแฝง'},
        ],
        'pagination': {'cursor': 'store_cursor_3', 'has_more': 'yes'},
      },
    });

    expect(storeListAlias.items.single.name, 'ร้านนามแฝง');
    expect(storeListAlias.nextCursor, 'store_cursor_3');
    expect(storeListAlias.hasMore, isTrue);
  });

  test('store lottery parser accepts legacy result lotteries and pagination',
      () {
    final page = StoreLotteryPage.fromJson({
      'result': {
        'lotteries': [
          {
            'id': 'vstock:game_1:987654:1',
            'fullNumber': 'draw-2026-987654',
            'seller_name': 'ร้านเลขท้าย',
            'price': {'amount': 8000, 'currency': 'THB'},
          },
        ],
        'pagination': {
          'game_id': 'game_legacy_store',
          'next_cursor': 'store_cursor_2',
          'has_more': true,
        },
        'seller': {'name': 'ร้านเลขท้าย'},
        'can_buy': 'false',
      },
    });

    expect(page.items.single.number, '987654');
    expect(page.items.single.sellerName, 'ร้านเลขท้าย');
    expect(page.items.single.price, 80);
    expect(page.gameId, 'game_legacy_store');
    expect(page.nextCursor, 'store_cursor_2');
    expect(page.hasMore, isTrue);
    expect(page.sellerName, 'ร้านเลขท้าย');
    expect(page.canReserve, isFalse);
  });

  test('stock parsers normalize unavailable availability statuses', () {
    final stockPage = LotteryStockPage.fromJson({
      'data': [
        {
          'id': 'sold_1',
          'full_number': '111111',
          'availability_status': 'SOLD_OUT',
        },
        {
          'id': 'booked_1',
          'full_number': '222222',
          'status': 'Booked',
        },
        {
          'id': 'allocated_1',
          'full_number': '333333',
          'status': 'Allocated',
        },
      ],
    });
    final storePage = StoreLotteryPage.fromJson({
      'data': [
        {
          'id': 'unavailable_store_1',
          'full_number': '444444',
          'availability_status': 'UNAVAILABLE',
        },
        {
          'id': 'available_store_1',
          'full_number': '555555',
          'status': 'Allocated',
        },
      ],
    });

    expect(stockPage.items[0].status, 'sold_out');
    expect(stockPage.items[0].isAvailable, isFalse);
    expect(stockPage.items[1].status, 'booked');
    expect(stockPage.items[1].isAvailable, isFalse);
    expect(stockPage.items[2].status, 'allocated');
    expect(stockPage.items[2].isAvailable, isTrue);
    expect(storePage.items[0].status, 'unavailable');
    expect(storePage.items[0].isAvailable, isFalse);
    expect(storePage.items[1].status, 'allocated');
    expect(storePage.items[1].isAvailable, isTrue);
  });

  test('lottery stock parser keeps virtual stock references and random page',
      () {
    final page = LotteryStockPage.fromJson({
      'data': [
        {
          'id': 'vstock:game:273707:1',
          'full_number': '273707',
          'store_name': 'พบโชค',
          'price': {'amount': 8000, 'currency': 'THB'},
          'remaining_count': 5,
        },
      ],
      'meta': {
        'game_id': 'game_1',
        'next_cursor': 'cursor_1',
        'has_more': true,
      },
    });

    expect(page.gameId, 'game_1');
    expect(page.nextCursor, 'cursor_1');
    expect(page.hasMore, isTrue);
    expect(page.canReserve, isTrue);
    expect(page.items.single.localStockItemId, 'vstock:game:273707:1');
    expect(page.items.single.number, '273707');
    expect(page.items.single.price, 80);
  });

  test('lottery stock parser maps legacy bet status and pagination', () {
    final page = LotteryStockPage.fromJson({
      'result': {
        'lotteries': [
          {
            'id': 'vstock:game:123456:1',
            'full_number': '123456',
            'store_name': 'พบโชค',
          },
        ],
        'pagination': {
          'game_id': 'game_legacy',
          'next_cursor': 'legacy_cursor',
          'has_more': true,
        },
        'bet_status': 0,
      },
    });

    expect(page.gameId, 'game_legacy');
    expect(page.nextCursor, 'legacy_cursor');
    expect(page.hasMore, isTrue);
    expect(page.canReserve, isFalse);
    expect(page.items.single.number, '123456');
  });

  test('stock page parsers accept numeric and string has_more aliases', () {
    final stockPage = LotteryStockPage.fromJson({
      'result': {
        'lotteries': [
          {'id': 'stock_legacy_1', 'full_number': '111111'},
        ],
        'pagination': {
          'next_cursor': 'stock_cursor_2',
          'has_more': '1',
        },
      },
    });
    final storeStockPage = StoreLotteryPage.fromJson({
      'result': {
        'lotteries': [
          {'id': 'store_stock_legacy_1', 'full_number': '222222'},
        ],
        'pagination': {
          'next_cursor': 'store_cursor_2',
          'has_more': 1,
        },
      },
    });
    final exhaustedStockPage = LotteryStockPage.fromJson({
      'result': {
        'lotteries': [
          {'id': 'stock_legacy_2', 'full_number': '333333'},
        ],
        'pagination': {'has_more': 'no'},
      },
    });

    expect(stockPage.hasMore, isTrue);
    expect(stockPage.nextCursor, 'stock_cursor_2');
    expect(storeStockPage.hasMore, isTrue);
    expect(storeStockPage.nextCursor, 'store_cursor_2');
    expect(exhaustedStockPage.hasMore, isFalse);
  });

  test('page parsers keep metadata from production wrapper shapes', () {
    final stock = LotteryStockPage.fromJson({
      'resource': {
        'data': [
          {'id': 'stock_1', 'full_number': '111111'},
        ],
        'meta': {
          'game_id': 'game_resource',
          'next_cursor': 'stock_cursor',
          'has_more': true,
          'seller_name': 'ร้าน resource',
        },
      },
    });
    final storeTickets = StoreLotteryPage.fromJson({
      'result': {
        'data': [
          {'id': 'store_stock_1', 'full_number': '222222'},
        ],
        'meta': {
          'game_id': 'game_result',
          'next_cursor': 'store_cursor',
          'has_more': true,
          'seller_name': 'ร้าน result',
        },
      },
    });
    final tickets = TicketPage.fromJson({
      'data': {
        'data': [
          {'id': 'ticket_1', 'number': '333333'},
        ],
        'meta': {'next_cursor': 'ticket_cursor', 'has_more': true, 'total': 9},
      },
    });
    final rewardClaims = RewardClaimPage.fromJson({
      'resource': {
        'items': [
          {'id': 'claim_1', 'status': 'submitted'},
        ],
        'meta': {'next_cursor': 'claim_cursor', 'has_more': true},
      },
    });
    final activityClaims = ActivityClaimPage.fromJson({
      'result': {
        'items': [
          {'id': 'activity_claim_1', 'status': 'approved'},
        ],
        'meta': {'next_cursor': 'activity_claim_cursor', 'has_more': true},
      },
    });
    final history = PurchaseHistoryPage.fromJson({
      'result': {
        'items': [
          {'id': 'order_1', 'total': 80},
        ],
        'meta': {'current_page': 2, 'last_page': 4},
      },
    });
    final awards = ActivityAwardPage.fromJson({
      'resource': {
        'data': [
          {'id': 'award_1', 'amount': 100, 'status': 'claimable'},
        ],
        'meta': {'next_cursor': 'award_cursor', 'has_more': true},
      },
    });

    expect(stock.gameId, 'game_resource');
    expect(stock.nextCursor, 'stock_cursor');
    expect(stock.hasMore, isTrue);
    expect(stock.sellerName, 'ร้าน resource');
    expect(storeTickets.gameId, 'game_result');
    expect(storeTickets.nextCursor, 'store_cursor');
    expect(storeTickets.hasMore, isTrue);
    expect(storeTickets.sellerName, 'ร้าน result');
    expect(tickets.nextCursor, 'ticket_cursor');
    expect(tickets.hasMore, isTrue);
    expect(tickets.total, 9);
    expect(rewardClaims.nextCursor, 'claim_cursor');
    expect(rewardClaims.hasMore, isTrue);
    expect(activityClaims.nextCursor, 'activity_claim_cursor');
    expect(activityClaims.hasMore, isTrue);
    expect(history.currentPage, 2);
    expect(history.lastPage, 4);
    expect(history.hasMore, isTrue);
    expect(awards.nextCursor, 'award_cursor');
    expect(awards.hasMore, isTrue);
  });

  test('lottery cart parser flattens reservations and totals', () {
    final cart = LotteryCart.fromJson({
      'server_time': '2026-06-25T10:00:00+07:00',
      'reservations': [
        {
          'id': 'res_1',
          'game_id': 'game_1',
          'expires_in_seconds': 600,
          'items': [
            {
              'id': 'vstock:game:273707:1',
              'full_number': '273707',
              'price': {'amount': 8000, 'currency': 'THB'},
            },
          ],
          'total': {'amount': 8000, 'currency': 'THB'},
        },
      ],
      'total': {'amount': 8000, 'currency': 'THB'},
      'item_count': 1,
    });

    expect(cart.itemCount, 1);
    expect(cart.total, 80);
    expect(cart.reservationIds, ['res_1']);
    expect(cart.reservations.single.serverTime, '2026-06-25T10:00:00+07:00');
    expect(cart.items.single.reservationId, 'res_1');
    expect(cart.items.single.serverTime, '2026-06-25T10:00:00+07:00');
  });

  test('lottery reservation parser accepts nested reservation resource', () {
    final reservation = LotteryReservation.fromJson({
      'reservation': {
        'id': 'res_nested_resource',
        'game_id': 'game_nested_resource',
        'status': 'active',
        'expires_at': '2026-06-25T10:30:00+07:00',
        'expires_in_seconds': '900',
        'server_time': '2026-06-25T10:15:00+07:00',
        'items': [
          {
            'local_stock_item_id': 'nested_resource_stock_1',
            'full_number': '445566',
            'price': {'amount': 8000, 'currency': 'THB'},
          },
        ],
        'total': {'amount': 8000, 'currency': 'THB'},
      },
    });

    expect(reservation.id, 'res_nested_resource');
    expect(reservation.gameId, 'game_nested_resource');
    expect(reservation.status, 'active');
    expect(reservation.expiresAt, '2026-06-25T10:30:00+07:00');
    expect(reservation.expiresInSeconds, 900);
    expect(reservation.serverTime, '2026-06-25T10:15:00+07:00');
    expect(reservation.total, 80);
    expect(reservation.items.single.number, '445566');
    expect(reservation.items.single.reservationId, 'res_nested_resource');
    expect(
      reservation.items.single.reservationExpiresAt,
      '2026-06-25T10:30:00+07:00',
    );
    expect(reservation.items.single.serverTime, '2026-06-25T10:15:00+07:00');
  });

  test('lottery cart parser accepts legacy flat carts payload', () {
    final cart = LotteryCart.fromJson({
      'server_time': '2026-06-25T10:00:00+07:00',
      'carts': [
        {
          'reservation_id': 'res_legacy_1',
          'game_id': 'game_legacy',
          'local_stock_item_id': 'legacy_stock_1',
          'number': '123456',
          'store_name': 'ร้าน legacy',
          'price': 80,
          'exp': '2026-06-25T10:15:00+07:00',
        },
        {
          'reservation_id': 'res_legacy_2',
          'game_id': 'game_legacy',
          'local_stock_item_id': 'legacy_stock_2',
          'number': '654321',
          'store_name': 'ร้าน legacy',
          'price': {'amount': 8000, 'currency': 'THB'},
          'exp': '2026-06-25T10:15:00+07:00',
        },
      ],
      'total': 160,
      'count': 2,
    });

    expect(cart.itemCount, 2);
    expect(cart.total, 160);
    expect(cart.reservationIds, ['res_legacy_1', 'res_legacy_2']);
    expect(cart.items.map((item) => item.number), ['123456', '654321']);
    expect(cart.items.first.storeName, 'ร้าน legacy');
    expect(cart.reservations.first.expiresAt, '2026-06-25T10:15:00+07:00');
  });

  test('lottery cart parser accepts legacy result cart_order lotteries', () {
    final cart = LotteryCart.fromJson({
      'result': {
        'cart_order': {
          'exp': '2026-06-25T10:20:00+07:00',
          'created_at': '2026-06-25T10:00:00+07:00',
          'lotteries': [
            {
              'reservation_id': 'res_nested_1',
              'game_id': 'game_nested',
              'local_stock_item_id': 'nested_stock_1',
              'lottery_number': '777777',
              'price': {'amount': 8000, 'currency': 'THB'},
            },
          ],
        },
      },
    });

    expect(cart.itemCount, 1);
    expect(cart.total, 80);
    expect(cart.reservationIds, ['res_nested_1']);
    expect(cart.items.single.number, '777777');
    expect(cart.reservations.single.expiresAt, '2026-06-25T10:20:00+07:00');
    expect(cart.serverTime, '2026-06-25T10:00:00+07:00');
  });

  test('lottery checkout parser maps paid order summary', () {
    final order = LotteryCheckoutOrder.fromJson({
      'id': 'ord_1',
      'reference': 'ORDER-1',
      'status': 'paid',
      'payment_status': 'paid',
      'payment_method': 'wallet',
      'total': {'amount': 16000, 'currency': 'THB'},
      'ticket_count': 2,
    });

    expect(order.id, 'ord_1');
    expect(order.total, 160);
    expect(order.ticketCount, 2);
  });

  test('lottery checkout parser accepts legacy nested order payloads', () {
    final order = LotteryCheckoutOrder.fromJson({
      'result': {
        'order': {
          'id': 'ord_nested',
          'reference': 'ORDER-NESTED',
          'status': 'paid',
          'payment_status': 'paid',
          'payment_method': 'wallet',
          'total': {'amount': 8000, 'currency': 'THB'},
          'ticket_count': 1,
          'paid_at': '2026-06-29T12:15:00+07:00',
        },
      },
    });

    expect(
      checkoutOrderPayload({
        'result': {
          'order': {'id': 'ord_nested'},
        },
      }),
      {
        'id': 'ord_nested',
      },
    );
    expect(order.id, 'ord_nested');
    expect(order.reference, 'ORDER-NESTED');
    expect(order.total, 80);
    expect(order.ticketCount, 1);
  });

  test('lottery checkout parser keeps wrapper metadata for nested orders', () {
    final payload = {
      'result': {
        'redirect_url': 'https://pay.example.test/session/ord_wrapper',
        'payment': {
          'provider_reference': 'PAY-WRAPPER',
          'redirect_url': 'https://pay.example.test/session/payment_wrapper',
          'completedAt': '2026-06-29T12:30:00+07:00',
        },
        'order': {
          'order_id': 'ord_wrapper',
          'status': 'pending_payment',
          'paymentStatus': 'pending_payment',
          'paymentMethod': 'external_payment',
          'amount': {'amount': 8000, 'currency': 'THB'},
          'count': '1',
        },
      },
    };
    final order = LotteryCheckoutOrder.fromJson(payload);

    expect(checkoutOrderPayload(payload), {
      'redirect_url': 'https://pay.example.test/session/ord_wrapper',
      'payment': {
        'provider_reference': 'PAY-WRAPPER',
        'redirect_url': 'https://pay.example.test/session/payment_wrapper',
        'completedAt': '2026-06-29T12:30:00+07:00',
      },
      'order_id': 'ord_wrapper',
      'status': 'pending_payment',
      'paymentStatus': 'pending_payment',
      'paymentMethod': 'external_payment',
      'amount': {'amount': 8000, 'currency': 'THB'},
      'count': '1',
    });
    expect(order.id, 'ord_wrapper');
    expect(order.reference, 'PAY-WRAPPER');
    expect(order.paymentStatus, 'pending_payment');
    expect(order.paymentMethod, 'external_payment');
    expect(order.total, 80);
    expect(order.ticketCount, 1);
    expect(order.paidAt, '2026-06-29T12:30:00+07:00');
    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_wrapper'),
    );
  });

  test('lottery checkout parser accepts production checkoutOrder wrappers', () {
    final payload = {
      'data': {
        'resource': {
          'redirectUrl': 'https://pay.example.test/session/ord_production',
          'payment': {
            'providerReference': 'PAY-PRODUCTION',
            'completed_at': '2026-06-29T12:45:00+07:00',
          },
          'checkoutOrder': {
            'checkoutOrderId': 'ord_production',
            'orderReference': 'ORDER-PRODUCTION',
            'orderStatus': 'pending_payment',
            'paymentMethod': 'external_payment',
            'grandTotal': {'amount': 24000, 'currency': 'THB'},
            'orderItems': [
              {'count': 2},
              {'quantity': 1},
            ],
          },
        },
      },
    };
    final order = LotteryCheckoutOrder.fromJson(payload);

    expect(order.id, 'ord_production');
    expect(order.reference, 'ORDER-PRODUCTION');
    expect(order.status, 'pending_payment');
    expect(order.paymentMethod, 'external_payment');
    expect(order.total, 240);
    expect(order.ticketCount, 3);
    expect(order.paidAt, '2026-06-29T12:45:00+07:00');
    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_production'),
    );
  });

  test('lottery checkout parser maps safe external redirect URLs', () {
    final order = LotteryCheckoutOrder.fromJson({
      'result': {
        'order': {
          'id': 'ord_external',
          'status': 'pending_payment',
          'payment_status': 'pending_payment',
          'payment_method': 'external_payment',
          'total': {'amount': 8000, 'currency': 'THB'},
          'payment': {
            'redirect_url': 'https://pay.example.test/session/ord_external',
          },
        },
      },
    });
    final providerWrapped = LotteryCheckoutOrder.fromJson({
      'data': {
        'resource': {
          'order': {
            'id': 'ord_provider_links',
            'status': 'pending_payment',
            'payment_status': 'pending_payment',
            'payment_method': 'external_payment',
            'total': {'amount': 8000, 'currency': 'THB'},
          },
          'payment': {
            'links': [
              {
                'rel': 'self',
                'href': 'https://api.example.test/orders/ord_provider_links',
              },
              {
                'rel': 'checkout',
                'href': 'https://pay.example.test/session/ord_provider_links',
              },
            ],
          },
        },
      },
    });
    final unsafe = LotteryCheckoutOrder.fromJson({
      'id': 'ord_unsafe',
      'payment_method': 'external_payment',
      'redirect_url': 'javascript:alert(1)',
    });

    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_external'),
    );
    expect(
      providerWrapped.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_provider_links'),
    );
    expect(unsafe.redirectUri, isNull);
  });

  test('ticket parser maps reward status, money, and image fields', () {
    final page = TicketPage.fromJson({
      'data': [
        {
          'id': 'ticket_1',
          'game_id': 'game_1',
          'draw_no': 16,
          'sort_order': 42,
          'game': {
            'name': 'งวดวันที่ 1 ก.ค. 2569',
            'draw_at': '2026-07-01T15:00:00+07:00',
          },
          'full_number': '287184',
          'status': 'winning',
          'reward_status': {
            'status': 'winning',
            'claimable': true,
            'prize_amount': {'amount': 400000, 'currency': 'THB'},
            'prizes': [
              {
                'prize_type': 'back2',
                'amount': {'amount': 400000, 'currency': 'THB'},
              },
            ],
          },
          'image_url': '/storage/tickets/full.webp',
          'image_thumb_url': '/storage/tickets/thumb.webp',
        },
      ],
      'meta': {'next_cursor': 'ticket_1', 'has_more': true, 'total': 1},
    });

    final ticket = page.items.single;
    expect(ticket.number, '287184');
    expect(ticket.drawNumber, '16');
    expect(ticket.setNumber, '42');
    expect(ticket.displayDrawNumber, '16');
    expect(ticket.displaySetNumber, '42');
    expect(ticket.claimable, isTrue);
    expect(ticket.prizeAmount, 4000);
    expect(ticket.rewardStatus.status, 'winning');
    expect(ticket.prizes.single.prizeType, 'back2');
    final th = CustomerLocalizations(fallbackCustomerLocale);
    const en = CustomerLocalizations(Locale('en', 'US'));
    expect(ticketStatusLabel(th, ticket), 'ถูกรางวัล');
    expect(ticketPrizeSummary(th, ticket), 'รางวัลเลขท้าย 2 ตัว');
    expect(ticketDrawDateText(th, ticket), '1 ก.ค. 2569');
    expect(ticketStatusLabel(en, ticket), 'Winning ticket');
    expect(ticketPrizeSummary(en, ticket), 'Last 2 digits');
    expect(ticket.primaryImageUrl, '/storage/tickets/full.webp');
    expect(page.hasMore, isTrue);
  });

  test('ticket parser maps legacy reward claim status and pagination aliases',
      () {
    CustomerTicket ticketFor({
      String status = '',
      String claimStatus = '',
      String rewardClaimId = '',
    }) {
      return CustomerTicket.fromJson({
        'id': 'ticket_$status$claimStatus',
        'status': 'winning',
        'reward_status': {
          'status': status,
          'claim_status': claimStatus,
          'claimable': true,
          'reward_claim_id': rewardClaimId,
          'prize_amount': {'amount': 200000, 'currency': 'THB'},
        },
      });
    }

    final page = TicketPage.fromJson({
      'result': {
        'tickets': [
          {
            'id': 'ticket_legacy_page_1',
            'full_number': '112233',
            'reward_status': {'status': 'claim_submitted'},
          },
        ],
        'pagination': {
          'cursor': 'ticket_cursor_2',
          'has_more': 'yes',
          'total': '1',
        },
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);
    const en = CustomerLocalizations(Locale('en', 'US'));
    final submitted = ticketFor(status: 'claim_submitted');
    final approved = ticketFor(claimStatus: 'claim_approved');
    final paidHyphen = ticketFor(claimStatus: 'claim-paid');
    final cancelled = ticketFor(status: 'claim_cancelled');
    final rejected = ticketFor(
      status: 'claim-rejected',
      rewardClaimId: 'rcl_retry',
    );

    expect(page.items.single.id, 'ticket_legacy_page_1');
    expect(page.nextCursor, 'ticket_cursor_2');
    expect(page.hasMore, isTrue);
    expect(page.total, 1);
    expect(ticketStatusLabel(th, submitted), 'รอรับเงินรางวัล');
    expect(ticketStatusLabel(th, approved), 'อนุมัติแล้ว');
    expect(ticketStatusLabel(en, approved), 'Claim approved');
    expect(ticketStatusLabel(th, paidHyphen), 'ขึ้นเงินแล้ว');
    expect(paidHyphen.rewardStatus.claimStatus, 'claim_paid');
    expect(ticketStatusLabel(th, cancelled), 'ยกเลิกขึ้นเงิน');
    expect(ticketStatusLabel(th, rejected), 'ขึ้นเงินไม่สำเร็จ');
    expect(rejected.rewardStatus.status, 'claim_rejected');
    expect(rejected.canCreateClaim, isTrue);
  });

  test('ticket parser accepts camelCase ticket and reward aliases', () {
    final ticket = CustomerTicket.fromJson({
      'customerTicket': {
        'ticketId': 'ticket_camel',
        'orderId': 'order_camel',
        'gameId': 'game_camel',
        'gameName': 'งวดวันที่ 1 กรกฎาคม 2569',
        'drawDate': '2026-07-01T15:00:00+07:00',
        'drawNo': '18',
        'setNo': '7',
        'fullNumber': '123456',
        'status': 'winning',
        'claimable': 'yes',
        'rewardClaimId': 'rcl_top_level',
        'imageUrl': 'https://cdn.example.test/full.webp',
        'imageThumbUrl': 'https://cdn.example.test/thumb.webp',
        'previewImageUrl': 'https://cdn.example.test/preview.webp',
        'imageStatus': 'Ready',
        'imageError': 'runtime image message',
        'rewardStatus': {
          'status': 'winning',
          'claimStatus': 'claim_approved',
          'rewardAmount': {'amount': 200000, 'currency': 'THB'},
          'payoutMethod': 'walletCredit',
          'adminNote': 'อนุมัติแล้ว',
          'prizes': [
            {
              'rewardType': 'back2',
              'rewardNumber': '56',
              'rewardAmount': {'amount': 200000, 'currency': 'THB'},
            },
          ],
        },
      },
    });
    final submission = RewardClaimSubmission.fromJson({
      'rewardClaim': {
        'claimId': 'rcl_submission_camel',
        'status': 'submitted',
        'createdAt': '2026-07-01T11:00:00+07:00',
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(ticket.id, 'ticket_camel');
    expect(ticket.orderId, 'order_camel');
    expect(ticket.gameId, 'game_camel');
    expect(ticket.gameName, 'งวดวันที่ 1 กรกฎาคม 2569');
    expect(ticket.drawNumber, '18');
    expect(ticket.setNumber, '7');
    expect(ticket.number, '123456');
    expect(ticket.claimable, isTrue);
    expect(ticket.rewardClaimId, 'rcl_top_level');
    expect(ticket.prizeAmount, 2000);
    expect(ticket.rewardStatus.claimStatus, 'claim_approved');
    expect(ticket.rewardStatus.payoutMethod, 'walletCredit');
    expect(ticket.rewardStatus.adminNote, 'อนุมัติแล้ว');
    expect(ticket.prizes.single.prizeType, 'back2');
    expect(ticket.prizes.single.prizeNumber, '56');
    expect(ticket.primaryImageUrl, 'https://cdn.example.test/full.webp');
    expect(ticket.thumbnailUrl, 'https://cdn.example.test/thumb.webp');
    expect(ticket.imageStatus, 'ready');
    expect(ticket.imageError, 'runtime image message');
    expect(ticketDrawDateText(th, ticket), '1 ก.ค. 2569');
    expect(submission.id, 'rcl_submission_camel');
    expect(submission.createdAt, '2026-07-01T11:00:00+07:00');
  });

  test('claim parsers accept wrapped ticket, status, and detail payloads', () {
    final ticket = CustomerTicket.fromJson({
      'ticket': {
        'id': 'ticket_wrapped',
        'full_number': '990011',
        'reward_status': {
          'reward_status': {
            'status': 'winning',
            'claimable': true,
            'prize_amount': {'amount': 200000, 'currency': 'THB'},
            'reward_claim_id': 'rcl_wrapped',
          },
        },
      },
    });
    final rewardStatus = TicketRewardStatus.fromJson({
      'reward_status': {
        'claim_status': 'claim_paid',
        'reward_claim_id': 'rcl_status_wrapped',
      },
    });
    final submission = RewardClaimSubmission.fromJson({
      'claim': {
        'id': 'rcl_submission_wrapped',
        'status': 'submitted',
        'submitted_at': '2026-07-01T11:00:00+07:00',
      },
    });
    final rewardClaim = RewardClaimItem.fromJson({
      'customer_name': 'ลูกค้า wrapper',
      'ticket': {'full_number': '990011'},
      'bank_account': {
        'bank_name': 'ธนาคารกรุงไทย',
        'account_number': '006123456789',
      },
      'reward_claim': {
        'id': 'rcl_detail_wrapped',
        'status': 'approved',
        'payout_method': 'bank_transfer',
        'payout_ledger_id': 'ledger_wrapped',
        'prize_amount': {'amount': 200000, 'currency': 'THB'},
      },
    });
    final activityClaim = ActivityClaimItem.fromJson({
      'customer_name': 'ลูกค้ากิจกรรม wrapper',
      'bank_account': {
        'bank_name': 'ธนาคารกสิกรไทย',
        'account_number': '1234567890',
      },
      'activity_claim': {
        'id': 'acl_detail_wrapped',
        'status': 'approved',
        'payout_method': 'bank_transfer',
        'payout_ledger_id': 'ledger_activity_wrapped',
        'claim_amount': {'amount': 150000, 'currency': 'THB'},
        'award': {
          'activity_name': 'ลุ้นรางวัล wrapper',
          'type': 'cashback',
        },
      },
    });

    expect(ticket.id, 'ticket_wrapped');
    expect(ticket.number, '990011');
    expect(ticket.claimable, isTrue);
    expect(ticket.rewardClaimId, 'rcl_wrapped');
    expect(ticket.prizeAmount, 2000);
    expect(rewardStatus.claimStatus, 'claim_paid');
    expect(rewardStatus.rewardClaimId, 'rcl_status_wrapped');
    expect(submission.id, 'rcl_submission_wrapped');
    expect(submission.createdAt, '2026-07-01T11:00:00+07:00');
    expect(rewardClaim.id, 'rcl_detail_wrapped');
    expect(rewardClaim.customerName, 'ลูกค้า wrapper');
    expect(rewardClaim.ticket?.number, '990011');
    expect(rewardClaim.isPaid, isTrue);
    expect(rewardClaim.bankName, 'ธนาคารกรุงไทย');
    expect(activityClaim.id, 'acl_detail_wrapped');
    expect(activityClaim.customerName, 'ลูกค้ากิจกรรม wrapper');
    expect(activityClaim.activityName, 'ลุ้นรางวัล wrapper');
    expect(activityClaim.amount, 1500);
    expect(activityClaim.isPaid, isTrue);
    expect(activityClaim.bankName, 'ธนาคารกสิกรไทย');
  });

  test('ticket claim parsers preserve data and result wrapper context', () {
    final ticket = CustomerTicket.fromJson({
      'rewardStatus': {
        'claimStatus': 'claim_paid',
        'rewardClaimId': 'rcl_outer',
        'prizes': [
          {
            'rewardType': 'front3',
            'rewardNumber': '123',
            'rewardAmount': {'amount': 400000, 'currency': 'THB'},
          },
        ],
      },
      'data': {
        'resource': {
          'customerTicket': {
            'ticketId': 'ticket_envelope',
            'orderId': 'order_envelope',
            'fullNumber': '123456',
            'drawNo': '18',
            'setNo': '7',
            'game': {
              'name': 'งวดวันที่ 1 กรกฎาคม 2569',
              'drawAt': '2026-07-01T15:00:00+07:00',
            },
            'imageStatus': 'READY',
          },
        },
      },
    });
    final rewardStatus = TicketRewardStatus.fromJson({
      'adminNote': 'อนุมัติจากระบบ',
      'result': {
        'resource': {
          'rewardStatus': {
            'claimStatus': 'claim_approved',
            'claimId': 'rcl_status_envelope',
            'rewardAmount': {'amount': 200000, 'currency': 'THB'},
          },
        },
      },
    });
    final submission = RewardClaimSubmission.fromJson({
      'submittedAt': '2026-07-01T12:34:00+07:00',
      'result': {
        'submission': {
          'claimId': 'rcl_submission_envelope',
          'status': 'submitted',
        },
      },
    });

    expect(ticket.id, 'ticket_envelope');
    expect(ticket.orderId, 'order_envelope');
    expect(ticket.number, '123456');
    expect(ticket.drawNumber, '18');
    expect(ticket.setNumber, '7');
    expect(ticket.gameName, 'งวดวันที่ 1 กรกฎาคม 2569');
    expect(ticket.rewardStatus.claimStatus, 'claim_paid');
    expect(ticket.rewardClaimId, 'rcl_outer');
    expect(ticket.prizeAmount, 4000);
    expect(ticket.prizes.single.prizeType, 'front3');
    expect(ticket.imageStatus, 'ready');
    expect(rewardStatus.claimStatus, 'claim_approved');
    expect(rewardStatus.rewardClaimId, 'rcl_status_envelope');
    expect(rewardStatus.prizeAmount, 2000);
    expect(rewardStatus.adminNote, 'อนุมัติจากระบบ');
    expect(submission.id, 'rcl_submission_envelope');
    expect(submission.createdAt, '2026-07-01T12:34:00+07:00');
  });

  test('affiliate overview maps stats, link, policy, and bank account', () {
    final overview = AffiliateOverview.fromJson({
      'is_affiliate': true,
      'affiliate': {
        'id': 'aff_1',
        'code': 'ABC123',
        'name': 'ร้านโชคดี',
        'wallet_balance': {'amount': 120000, 'currency': 'THB'},
      },
      'links': [
        {'code': 'ABC123', 'canonical_url': 'https://shop.test/?ref=ABC123'},
      ],
      'profile': {
        'name': 'ดีทู',
        'reward_payout_bank_account': {
          'bank_name': 'ธนาคารกรุงไทย',
          'account_name': 'ดีทู',
          'account_number': '1234567890',
        },
      },
      'stats': {
        'available_balance': {'amount': 99000, 'currency': 'THB'},
        'converted_count': 3,
        'visitor_count': 20,
        'registered_count': 5,
      },
      'payout_policy': {
        'minimum_payout_amount': {'amount': 30000, 'currency': 'THB'},
      },
      'commissions': [
        {
          'id': 'com_1',
          'order_id': 'ord_1',
          'amount': {'amount': 5000, 'currency': 'THB'},
        },
      ],
      'payouts': [
        {
          'id': 'pay_1',
          'payout_method': 'bank_transfer',
          'amount': {'amount': 30000, 'currency': 'THB'},
        },
      ],
    });

    expect(overview.storeName, 'ร้านโชคดี');
    expect(overview.referralCode, 'ABC123');
    expect(overview.referralUrl, 'https://shop.test/?ref=ABC123');
    expect(overview.stats.availableBalance, 990);
    expect(overview.payoutPolicy.minimumPayout, 300);
    expect(overview.bankAccount.maskedNumber, '******7890');
    expect(overview.commissions.single.amount, 50);
    expect(overview.payouts.single.amount, 300);
  });

  test('topup overview maps payment methods, waiting item, and money', () {
    final overview = TopupOverview.fromJson({
      'wallet': {
        'id': 'wallet_runtime',
        'displayName': 'Runtime Blue Wallet',
      },
      'payment_methods': [
        {'key': 'qr', 'enabled': true},
        {
          'key': 'credit_card',
          'label': 'Runtime Credit QR',
          'description': 'Runtime provider minimum applies',
          'logoUrl': 'https://cdn.example.test/credit-qr.png',
          'enabled': false,
          'minimum_amount': {'amount': 75000, 'currency': 'THB'},
        },
      ],
      'enabled_payment_methods': ['qr', 'bank_transfer'],
      'waiting': {
        'id': 'top_1',
        'amount': {'amount': 50000, 'currency': 'THB'},
        'status': 'processing',
        'channel': 'qr',
        'payment': {'qr_code': 'data:image/jpeg;base64,AAAA'},
      },
      'histories': [
        {
          'id': 'top_2',
          'amount': {'amount': 10000, 'currency': 'THB'},
          'status': 'approved',
          'channel': 'bank_transfer',
        },
      ],
      'meta': {'current_page': 1, 'last_page': 2},
    });

    expect(overview.isChannelEnabled(TopupChannel.qr), isTrue);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
    expect(overview.paymentMethods.map((method) => method.key), [
      'qr',
      'credit_card',
      'bank_transfer',
    ]);
    expect(overview.firstEnabledChannel, TopupChannel.qr);
    expect(overview.walletName, 'Runtime Blue Wallet');
    final credit = overview.methodForChannel(TopupChannel.creditCard);
    expect(credit?.label, 'Runtime Credit QR');
    expect(credit?.description, 'Runtime provider minimum applies');
    expect(credit?.iconUrl, 'https://cdn.example.test/credit-qr.png');
    expect(credit?.minimumAmount, 750);
    expect(overview.waiting?.amount, 500);
    expect(overview.waiting?.status, TopupStatus.pendingPayment);
    expect(overview.waiting?.needsSlip, isTrue);
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.lastPage, 2);
  });

  test('topup overview accepts legacy result pagination and channel aliases',
      () {
    final overview = TopupOverview.fromJson({
      'result': {
        'website_bank': {
          'bank': {'name': 'ธนาคารกรุงไทย'},
          'account_name': 'บริษัท ดี จำกัด',
          'account_number': '006123456789',
        },
        'methods': [
          {
            'channel': 'credit_qr',
            'enabled': true,
            'config': {
              'min_topup_amount': {'amount': 45000},
            },
          },
          {'channel': 'bank', 'enabled': true},
        ],
        'enabled_methods': ['credit_qr', 'bank'],
        'pending': {
          'id': 'top_legacy_pending',
          'amount': {'amount': 75000, 'currency': 'THB'},
          'status': 'processing',
          'channel': 'credit_qr',
          'payment': {
            'redirect_url': 'https://pay.example.test/top_legacy_pending',
          },
        },
        'history': [
          {
            'id': 'top_legacy_history',
            'amount': {'amount': 120000, 'currency': 'THB'},
            'status': '1',
            'channel': 'bank',
          },
        ],
        'pagination': {
          'page': 2,
          'total_page': 4,
        },
      },
    });

    expect(overview.bank.bankName, 'ธนาคารกรุงไทย');
    expect(overview.bank.accountName, 'บริษัท ดี จำกัด');
    expect(overview.isChannelEnabled(TopupChannel.qr), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isTrue);
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
    expect(overview.firstEnabledChannel, TopupChannel.creditCard);
    expect(
      overview.methodForChannel(TopupChannel.creditCard)?.minimumAmount,
      450,
    );
    expect(overview.waiting?.id, 'top_legacy_pending');
    expect(overview.waiting?.channel, TopupChannel.creditCard);
    expect(overview.waiting?.redirectUri, isNotNull);
    expect(overview.histories.single.id, 'top_legacy_history');
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.histories.single.channel, TopupChannel.bankTransfer);
    expect(overview.currentPage, 2);
    expect(overview.lastPage, 4);
  });

  test('topup overview accepts camelCase methods and topup wrappers', () {
    final overview = TopupOverview.fromJson({
      'data': {
        'websiteBank': {
          'bank': {'bankName': 'ธนาคารกรุงไทย'},
          'accountName': 'บริษัท ดี จำกัด',
          'accountNumber': '006123456789',
        },
        'paymentMethods': [
          {
            'paymentMethod': 'creditCard',
            'title': 'Runtime Credit QR',
            'subtitle': 'Runtime provider controls this channel',
            'isEnabled': 'true',
            'metadata': {
              'minimumTopupAmount': {'amount': 90000, 'currency': 'THB'},
            },
          },
          {
            'paymentMethod': 'qr',
            'disabled': true,
          },
        ],
        'enabledPaymentMethods': [
          {'paymentMethod': 'creditCard', 'enabled': true},
          {'paymentMethod': 'bankTransfer', 'enabled': false},
        ],
        'waitingTopup': {
          'topupId': 'top_camel_waiting',
          'topupAmount': {'amount': 90000, 'currency': 'THB'},
          'bonusAmount': {'amount': 1000, 'currency': 'THB'},
          'presentationStatus': 'pendingPayment',
          'paymentMethod': 'creditCard',
          'transferAt': '2026-07-01T10:00:00+07:00',
          'createdAt': '2026-07-01T09:50:00+07:00',
          'payment': {
            'providerName': 'runtime_provider',
            'qrCode': 'data:image/png;base64,CAMEL',
            'paymentUrl': 'https://pay.example.test/top_camel_waiting',
            'instructions': 'สแกน QR Code เพื่อชำระเงินรายการนี้',
          },
        },
        'topups': [
          {
            'depositId': 'top_camel_history',
            'depositAmount': {'amount': 50000, 'currency': 'THB'},
            'statusRaw': 'success',
            'paymentChannel': 'bankTransfer',
            'slip': {
              'fullUrl': 'https://cdn.example.test/slips/top_camel.jpg',
              'thumbUrl': 'https://cdn.example.test/slips/top_camel-thumb.jpg',
            },
          },
        ],
        'meta': {'currentPage': 3, 'totalPages': 5},
      },
    });

    expect(overview.bank.bankName, 'ธนาคารกรุงไทย');
    expect(overview.bank.accountName, 'บริษัท ดี จำกัด');
    expect(overview.bank.accountNumber, '006123456789');
    expect(overview.isChannelEnabled(TopupChannel.qr), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isTrue);
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isFalse);
    final credit = overview.methodForChannel(TopupChannel.creditCard);
    expect(credit?.label, 'Runtime Credit QR');
    expect(credit?.description, 'Runtime provider controls this channel');
    expect(credit?.minimumAmount, 900);
    expect(overview.waiting?.id, 'top_camel_waiting');
    expect(overview.waiting?.amount, 900);
    expect(overview.waiting?.bonusAmount, 10);
    expect(overview.waiting?.status, TopupStatus.pendingPayment);
    expect(overview.waiting?.channel, TopupChannel.creditCard);
    expect(overview.waiting?.provider, 'runtime_provider');
    expect(overview.waiting?.qrCode, 'data:image/png;base64,CAMEL');
    expect(
      overview.waiting?.redirectUri,
      Uri.parse('https://pay.example.test/top_camel_waiting'),
    );
    expect(overview.waiting?.message, 'สแกน QR Code เพื่อชำระเงินรายการนี้');
    expect(overview.waiting?.transferAt, '2026-07-01T10:00:00+07:00');
    expect(overview.waiting?.createdAt, '2026-07-01T09:50:00+07:00');
    expect(overview.histories.single.id, 'top_camel_history');
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.histories.single.channel, TopupChannel.bankTransfer);
    expect(
      overview.histories.single.slipUrl,
      'https://cdn.example.test/slips/top_camel.jpg',
    );
    expect(
      overview.histories.single.slipThumbUrl,
      'https://cdn.example.test/slips/top_camel-thumb.jpg',
    );
    expect(overview.currentPage, 3);
    expect(overview.lastPage, 5);
  });

  test('topup overview preserves recursive resource wrapper context', () {
    final overview = TopupOverview.fromJson({
      'meta': {'currentPage': 4},
      'data': {
        'resource': {
          'topupOverview': {
            'websiteBank': {
              'bank': {'displayName': 'ธนาคารไทยพาณิชย์'},
              'bankAccountName': 'บริษัท Wrapper จำกัด',
              'bankAccountNumber': '9998887776',
            },
            'paymentMethods': [
              {
                'method': 'creditCard',
                'label': 'Runtime Wrapper Credit',
                'config': {
                  'minAmount': {'amount': 120000, 'currency': 'THB'},
                },
              },
            ],
            'enabledMethods': [
              {'method': 'creditCard', 'enabled': true},
              {'method': 'qr', 'enabled': false},
            ],
            'pendingTopup': {
              'request': {
                'requestId': 'top_recursive_waiting',
                'amount': {'amount': 120000, 'currency': 'THB'},
                'presentationStatus': 'pendingPayment',
                'paymentMethod': 'creditCard',
              },
              'payment': {
                'providerName': 'recursive_provider',
                'redirectUrl': 'https://pay.example.test/top_recursive',
                'paymentMessage': 'ชำระผ่านผู้ให้บริการ',
              },
            },
            'history': [
              {
                'data': {
                  'resource': {
                    'depositId': 'top_recursive_history',
                    'depositAmount': {'amount': 75000, 'currency': 'THB'},
                    'statusRaw': 'completed',
                    'paymentChannel': 'bankTransfer',
                  },
                },
              },
            ],
            'pagination': {'totalPages': 6},
          },
        },
      },
    });

    expect(overview.bank.bankName, 'ธนาคารไทยพาณิชย์');
    expect(overview.bank.accountName, 'บริษัท Wrapper จำกัด');
    expect(overview.bank.accountNumber, '9998887776');
    expect(overview.isChannelEnabled(TopupChannel.qr), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isTrue);
    final credit = overview.methodForChannel(TopupChannel.creditCard);
    expect(credit?.label, 'Runtime Wrapper Credit');
    expect(credit?.minimumAmount, 1200);
    expect(overview.waiting?.id, 'top_recursive_waiting');
    expect(overview.waiting?.channel, TopupChannel.creditCard);
    expect(overview.waiting?.provider, 'recursive_provider');
    expect(
      overview.waiting?.redirectUri,
      Uri.parse('https://pay.example.test/top_recursive'),
    );
    expect(overview.waiting?.message, 'ชำระผ่านผู้ให้บริการ');
    expect(overview.histories.single.id, 'top_recursive_history');
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.histories.single.channel, TopupChannel.bankTransfer);
    expect(overview.currentPage, 4);
    expect(overview.lastPage, 6);
  });

  test('topup overview accepts recursive page resource wrappers', () {
    final overview = TopupOverview.fromJson({
      'meta': {'currentPage': 5},
      'data': {
        'resource': {
          'topupHistoryPage': {
            'websiteBank': {
              'bank': {'displayName': 'ธนาคารหน้าเพจ'},
              'bankAccountName': 'บริษัท Page จำกัด',
              'bankAccountNumber': '1112223334',
            },
            'paymentMethods': [
              {
                'method': 'qr',
                'title': 'Runtime Page QR',
                'active': true,
              },
            ],
            'enabledPaymentMethods': [
              {'method': 'qr', 'enabled': true},
            ],
            'pendingRequests': [
              {
                'id': 'top_page_done',
                'amount': {'amount': 10000, 'currency': 'THB'},
                'status': 'approved',
                'channel': 'qr',
              },
              {
                'topup': {
                  'topupId': 'top_page_waiting',
                  'topupAmount': {'amount': 65000, 'currency': 'THB'},
                  'presentationStatus': 'pendingPayment',
                  'paymentMethod': 'qr',
                },
                'payment': {
                  'qrCode': 'data:image/png;base64,PAGE_WAITING',
                },
              },
            ],
            'items': [
              {
                'topup': {
                  'topupId': 'top_page_history',
                  'topupAmount': {'amount': 125000, 'currency': 'THB'},
                  'statusRaw': 'success',
                  'paymentMethod': 'bankTransfer',
                },
              },
            ],
            'pagination': {'lastPage': 9},
          },
        },
      },
    });

    expect(overview.bank.bankName, 'ธนาคารหน้าเพจ');
    expect(overview.bank.accountName, 'บริษัท Page จำกัด');
    expect(overview.bank.accountNumber, '1112223334');
    expect(overview.isChannelEnabled(TopupChannel.qr), isTrue);
    expect(
      overview.methodForChannel(TopupChannel.qr)?.label,
      'Runtime Page QR',
    );
    expect(overview.waiting?.id, 'top_page_waiting');
    expect(overview.waiting?.amount, 650);
    expect(overview.waiting?.status, TopupStatus.pendingPayment);
    expect(overview.waiting?.qrCode, 'data:image/png;base64,PAGE_WAITING');
    expect(overview.histories.single.id, 'top_page_history');
    expect(overview.histories.single.amount, 1250);
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.histories.single.channel, TopupChannel.bankTransfer);
    expect(overview.currentPage, 5);
    expect(overview.lastPage, 9);
  });

  test('topup overview accepts waiting lists and keeps active request', () {
    final overview = TopupOverview.fromJson({
      'data': {
        'pendingTopups': [
          {
            'id': 'top_done',
            'amount': {'amount': 10000, 'currency': 'THB'},
            'status': 'approved',
            'channel': 'qr',
          },
          {
            'request': {
              'id': 'top_waiting_list',
              'amount': {'amount': 50000, 'currency': 'THB'},
              'presentationStatus': 'pendingPayment',
              'paymentMethod': 'credit_qr',
            },
            'payment': {
              'qrCode': 'data:image/png;base64,WAITING_LIST',
            },
          },
        ],
      },
    });

    expect(overview.waiting?.id, 'top_waiting_list');
    expect(overview.waiting?.amount, 500);
    expect(overview.waiting?.status, TopupStatus.pendingPayment);
    expect(overview.waiting?.channel, TopupChannel.creditCard);
    expect(overview.waiting?.qrCode, 'data:image/png;base64,WAITING_LIST');
  });

  test('topup bank account maps legacy bank and account field variants', () {
    final legacy = TopupOverview.fromJson({
      'bank': {
        'bank': {'bank_name': 'ธนาคารกรุงไทย'},
        'account_name': 'บริษัท ดี จำกัด',
        'account_number': '006123456789',
      },
    });
    final sparse = TopupOverview.fromJson({
      'bank': {
        'bank': {'name': ''},
        'bank_label': 'ธนาคารไทยพาณิชย์',
        'bank_deposit_name': '',
        'bank_account_name': 'ร้านโชคดี',
        'bank_deposit_number': '',
        'bank_account_no': '0141234567',
      },
    });

    expect(legacy.bank.bankName, 'ธนาคารกรุงไทย');
    expect(legacy.bank.accountName, 'บริษัท ดี จำกัด');
    expect(legacy.bank.accountNumber, '006123456789');
    expect(legacy.bank.isConfigured, isTrue);
    expect(sparse.bank.bankName, 'ธนาคารไทยพาณิชย์');
    expect(sparse.bank.accountName, 'ร้านโชคดี');
    expect(sparse.bank.accountNumber, '0141234567');
  });

  test('topup overview accepts runtime bank account list aliases', () {
    final overview = TopupOverview.fromJson({
      'website_banks': [
        {
          'bank': {'name': 'กรุงไทย'},
          'bank_deposit_name': 'ร้านหนึ่ง',
          'bank_deposit_number': '1112223334',
          'bank_logo_url': 'https://cdn.example.test/ktb.png',
        },
        {
          'bankName': 'กสิกรไทย',
          'accountName': 'ร้านสอง',
          'accountNumber': '5556667778',
        },
      ],
      'enabled_payment_methods': ['bank_transfer'],
    });

    expect(overview.banks, hasLength(2));
    expect(overview.banks.first.bankName, 'กรุงไทย');
    expect(overview.banks.first.accountName, 'ร้านหนึ่ง');
    expect(overview.banks.first.accountNumber, '1112223334');
    expect(overview.banks.first.iconUrl, 'https://cdn.example.test/ktb.png');
    expect(overview.banks.last.bankName, 'กสิกรไทย');
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
  });

  test('topup overview keeps three channels and disables missing methods', () {
    final partial = TopupOverview.fromJson({
      'payment_methods': [
        {'key': 'credit_qr', 'enabled': true},
      ],
    });
    final legacy = TopupOverview.fromJson({});

    expect(partial.paymentMethods.map((method) => method.key), [
      'qr',
      'credit_card',
      'bank_transfer',
    ]);
    expect(partial.isChannelEnabled(TopupChannel.qr), isFalse);
    expect(partial.isChannelEnabled(TopupChannel.creditCard), isTrue);
    expect(partial.isChannelEnabled(TopupChannel.bankTransfer), isFalse);
    expect(partial.firstEnabledChannel, TopupChannel.creditCard);

    expect(legacy.paymentMethods, isEmpty);
    expect(legacy.isChannelEnabled(TopupChannel.qr), isTrue);
    expect(legacy.isChannelEnabled(TopupChannel.creditCard), isTrue);
    expect(legacy.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
  });

  test('topup overview accepts keyed payment method config maps', () {
    final overview = TopupOverview.fromJson({
      'payment_methods': {
        'qr': {
          'label': 'Runtime QR',
          'status': 'ready',
          'metadata': {
            'minimumAmount': {'amount': 10000, 'currency': 'THB'},
          },
        },
        'credit_card': {
          'label': 'Runtime Credit',
          'status': 'disabled',
        },
        'bank_transfer': true,
      },
      'enabled_payment_methods': {
        'qr': {'status': 'active'},
        'credit_card': false,
        'bankTransfer': {'enabled': true},
      },
    });

    expect(overview.paymentMethods.map((method) => method.key), [
      'qr',
      'credit_card',
      'bank_transfer',
    ]);
    expect(overview.isChannelEnabled(TopupChannel.qr), isTrue);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
    expect(overview.methodForChannel(TopupChannel.qr)?.label, 'Runtime QR');
    expect(overview.methodForChannel(TopupChannel.qr)?.minimumAmount, 100);
    expect(
      overview.methodForChannel(TopupChannel.creditCard)?.label,
      'Runtime Credit',
    );
  });

  test('topup overview accepts nested BO payment config aliases', () {
    final overview = TopupOverview.fromJson({
      'data': {
        'paymentConfig': {
          'methods': [
            'promptPay',
            {
              'provider': 'manual',
              'displayName': 'Manual bank transfer',
              'supported': true,
              'minimumAmount': {'amount': 20000, 'currency': 'THB'},
            },
            {
              'code': 'creditCard',
              'label': 'Runtime credit',
              'isSupported': false,
            },
          ],
          'enabledMethods': {
            'promptPay': {'available': 'on'},
            'manual': {'allowed': true},
            'creditCard': {'isSupported': false},
          },
        },
        'pendingTopup': {
          'topupId': 'top_promptpay_waiting',
          'amount': {'amount': 50000, 'currency': 'THB'},
          'status': 'pending_payment',
          'paymentMethod': 'promptPay',
        },
      },
    });

    expect(overview.paymentMethods.map((method) => method.key), [
      'qr',
      'credit_card',
      'bank_transfer',
    ]);
    expect(overview.isChannelEnabled(TopupChannel.qr), isTrue);
    expect(overview.isChannelEnabled(TopupChannel.creditCard), isFalse);
    expect(overview.isChannelEnabled(TopupChannel.bankTransfer), isTrue);
    expect(
      overview.methodForChannel(TopupChannel.bankTransfer)?.label,
      'Manual bank transfer',
    );
    expect(
      overview.methodForChannel(TopupChannel.bankTransfer)?.minimumAmount,
      200,
    );
    expect(overview.waiting?.id, 'top_promptpay_waiting');
    expect(overview.waiting?.channel, TopupChannel.qr);
  });

  test('topup redirect URL maps to safe external payment URI', () {
    final item = TopupRequestItem.fromJson({
      'id': 'top_1',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'processing',
      'channel': 'credit_card',
      'payment': {'paymentUrl': 'https://pay.example.test/session/123'},
    });
    final nested = TopupRequestItem.fromJson({
      'id': 'top_nested',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'processing',
      'channel': 'credit_card',
      'paymentSession': {
        'links': [
          {
            'rel': 'self',
            'href': 'https://api.example.test/topups/top_nested',
          },
          {
            'rel': 'checkout',
            'href': 'https://pay.example.test/session/top_nested',
          },
        ],
      },
    });
    final unsafe = TopupRequestItem.fromJson({
      'id': 'top_2',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'processing',
      'channel': 'credit_card',
      'payment': {'redirect_url': 'javascript:alert(1)'},
    });

    expect(item.redirectUri, Uri.parse('https://pay.example.test/session/123'));
    expect(
      nested.redirectUri,
      Uri.parse('https://pay.example.test/session/top_nested'),
    );
    expect(unsafe.redirectUri, isNull);
  });

  test('topup item parser accepts legacy detail and create wrappers', () {
    final detail = TopupRequestItem.fromJson({
      'deposit': {
        'id': 'top_detail',
        'amount': {'amount': 65000, 'currency': 'THB'},
        'bonus_amount': {'amount': 5000, 'currency': 'THB'},
        'status_raw': 'processing',
        'payment_method': 'credit_qr',
        'provider': 'deepay_kbank',
        'slip': {
          'url': 'https://cdn.example.test/slips/top_detail.jpg',
        },
      },
      'payment': {
        'qrCode': 'data:image/png;base64,DETAIL',
        'checkout_url': 'https://pay.example.test/top_detail',
        'payment_message': 'สแกน QR Code เพื่อชำระเงินรายการนี้',
        'provider': 'runtime_provider',
      },
    });
    final created = TopupRequestItem.fromJson({
      'data': {
        'result': {
          'id': 'top_created',
          'amount': 400,
          'status': 'pending_review',
          'method': 'bank',
        },
        'qr_code': 'data:image/png;base64,WRAPPER',
        'message': 'สร้างรายการสำเร็จ',
      },
      'topup_id': 'top_created_fallback',
    });

    expect(detail.id, 'top_detail');
    expect(detail.amount, 650);
    expect(detail.bonusAmount, 50);
    expect(detail.status, TopupStatus.pendingPayment);
    expect(detail.channel, TopupChannel.creditCard);
    expect(detail.provider, 'deepay_kbank');
    expect(detail.qrCode, 'data:image/png;base64,DETAIL');
    expect(
      detail.redirectUri,
      Uri.parse('https://pay.example.test/top_detail'),
    );
    expect(detail.message, 'สแกน QR Code เพื่อชำระเงินรายการนี้');
    expect(detail.slipUrl, 'https://cdn.example.test/slips/top_detail.jpg');
    expect(
      detail.slipThumbUrl,
      'https://cdn.example.test/slips/top_detail.jpg',
    );
    expect(created.id, 'top_created');
    expect(created.amount, 400);
    expect(created.status, TopupStatus.pendingReview);
    expect(created.channel, TopupChannel.bankTransfer);
    expect(created.qrCode, 'data:image/png;base64,WRAPPER');
    expect(created.message, 'สร้างรายการสำเร็จ');
  });

  test('topup item maps legacy numeric statuses and slip object payloads', () {
    final approved = TopupRequestItem.fromJson({
      'id': 'top_approved',
      'amount': '500',
      'status': 1,
      'channel': 'qr_code',
      'slip': {
        'full_url': 'https://cdn.example.test/slips/top_approved.jpg',
        'thumb_url': 'https://cdn.example.test/slips/top_approved-thumb.jpg',
      },
    });
    final pending = TopupRequestItem.fromJson({
      'id': 'top_pending',
      'amount': {'amount': 120000, 'currency': 'THB'},
      'status': '2',
      'channel': 'bank',
      'slip': 'https://cdn.example.test/slips/top_pending.jpg',
    });
    final rejected = TopupRequestItem.fromJson({
      'id': 'top_rejected',
      'amount': 100,
      'status': 0,
      'channel': 'credit_qr',
    });

    expect(approved.status, TopupStatus.approved);
    expect(approved.channel, TopupChannel.qr);
    expect(
      approved.slipUrl,
      'https://cdn.example.test/slips/top_approved.jpg',
    );
    expect(
      approved.slipThumbUrl,
      'https://cdn.example.test/slips/top_approved-thumb.jpg',
    );
    expect(pending.status, TopupStatus.pendingReview);
    expect(pending.channel, TopupChannel.bankTransfer);
    expect(pending.amount, 1200);
    expect(
      pending.slipUrl,
      'https://cdn.example.test/slips/top_pending.jpg',
    );
    expect(rejected.status, TopupStatus.rejected);
    expect(rejected.channel, TopupChannel.creditCard);
  });

  test('reward claim maps money, prizes, payout, and paid bank status', () {
    final claim = RewardClaimItem.fromJson({
      'id': 'rcl_1',
      'reference': 'RWD-0001',
      'status': 'approved',
      'payout_method': 'bank_transfer',
      'prize_amount': {'amount': 394000, 'currency': 'THB'},
      'bank_account': {
        'bank_name': 'ธนาคารกรุงไทย',
        'account_number': '006123456789',
      },
      'customer': {'name': 'วิรัตน์ ดวงดี'},
      'ticket': {
        'full_number': '123456',
        'game': {'name': 'งวดวันที่ 16 พฤษภาคม 2569'},
      },
      'prizes': [
        {
          'prize_type': 'back2',
          'amount': {'amount': 200000, 'currency': 'THB'},
        },
        {
          'prize_type': 'front3',
          'amount': {'amount': 194000, 'currency': 'THB'},
        },
      ],
    });

    expect(claim.prizeAmount, 3940);
    expect(claim.isPaid, isTrue);
    expect(claim.ticket?.number, '123456');
    expect(claim.status, RewardClaimStatus.approved);
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.prizes.map((prize) => prize.prizeType), ['back2', 'front3']);

    final th = CustomerLocalizations(fallbackCustomerLocale);
    const en = CustomerLocalizations(Locale('en', 'US'));
    expect(rewardClaimStatusLabel(th, claim), 'โอนเงินสำเร็จ');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีกรุงไทย');
    expect(
      rewardClaimPrizeNames(th, claim),
      containsAll(['รางวัลเลขท้าย 2 ตัว', 'รางวัลเลขหน้า 3 ตัว']),
    );
    expect(rewardClaimDrawDateText(th, claim.ticket), '16 พ.ค. 2569');
    expect(rewardClaimStatusLabel(en, claim), 'Paid successfully');
    expect(rewardClaimPayoutSummary(en, claim), 'Receive via กรุงไทย account');
    expect(
      rewardClaimPrizeNames(en, claim),
      containsAll(['Last 2 digits', 'Front 3 digits']),
    );
  });

  test('reward claim maps legacy payout ledger and bank account variants', () {
    final claim = RewardClaimItem.fromJson({
      'id': 'rcl_legacy',
      'status': 'approved',
      'payout_ledger_id': 'ledger_1',
      'payout_method': 'bank_transfer',
      'prize_amount': 1200,
      'customer_full_name': 'ลูกค้า Legacy',
      'bank_name': 'ธนาคารกรุงไทย',
      'bank_account_number': '006-123-4567',
      'wallet_name': 'Primary wallet',
    });

    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(claim.isPaid, isTrue);
    expect(claim.customerName, 'ลูกค้า Legacy');
    expect(claim.payoutLedgerId, 'ledger_1');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006-123-4567');
    expect(rewardClaimStatusLabel(th, claim), 'โอนเงินสำเร็จ');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีกรุงไทย');
    expect(rewardClaimPayoutChannelText(th, claim), 'ธนาคารกรุงไทย\nx xxx4567');
  });

  test('reward claim maps wrapped legacy ticket and payout aliases', () {
    final claim = RewardClaimItem.fromJson({
      'ticket_number': '654321',
      'ticket_id': 'ticket_legacy',
      'game_name': 'งวดวันที่ 1 กรกฎาคม 2569',
      'payout': {
        'ledger_id': 'ledger_wrapped_reward',
        'bank_account': {
          'bank': 'ธนาคารไทยพาณิชย์',
          'account_no': '1111222233',
        },
      },
      'reward_claim': {
        'id': 'rcl_wrapped',
        'claim_status': 'claim_paid',
        'amount': {'amount': 50000, 'currency': 'THB'},
        'reward_type': 'back2',
        'payout_channel': 'bank',
        'claimed_at': '2026-07-01T10:00:00+07:00',
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(claim.id, 'rcl_wrapped');
    expect(claim.status, RewardClaimStatus.paid);
    expect(claim.statusRaw, 'claim_paid');
    expect(claim.isPaid, isTrue);
    expect(claim.prizeAmount, 500);
    expect(claim.prizeType, 'back2');
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_wrapped_reward');
    expect(claim.bankName, 'ธนาคารไทยพาณิชย์');
    expect(claim.bankAccountNumber, '1111222233');
    expect(claim.ticket?.id, 'ticket_legacy');
    expect(claim.ticket?.number, '654321');
    expect(rewardClaimDrawDateText(th, claim.ticket), '1 ก.ค. 2569');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีไทยพาณิชย์');
    expect(
      formatLocalizedDateTime(claim.submittedAt, th.locale.toLanguageTag()),
      contains('1 ก.ค.'),
    );
  });

  test('reward claim parser accepts camelCase detail aliases', () {
    final claim = RewardClaimItem.fromJson({
      'ticketId': 'ticket_camel',
      'ticketNumber': '654321',
      'gameName': 'งวดวันที่ 1 กรกฎาคม 2569',
      'drawAt': '2026-07-01T15:00:00+07:00',
      'claim': {
        'id': 'rcl_camel',
        'claimReference': 'RWD-CAMEL',
        'claimStatus': 'claim_approved',
        'payoutMethod': 'bankTransfer',
        'payoutLedgerId': 'ledger_camel',
        'customerName': 'ลูกค้า Camel',
        'bankName': 'ธนาคารกรุงไทย',
        'bankAccountNumber': '006123456789',
        'walletName': 'Runtime Wallet',
        'paidAt': '2026-07-01T11:00:00+07:00',
        'adminNote': 'อนุมัติแล้ว',
        'prizes': [
          {
            'rewardType': 'back2',
            'rewardNumber': '21',
            'rewardAmount': {'amount': 394000, 'currency': 'THB'},
          },
        ],
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(claim.id, 'rcl_camel');
    expect(claim.displayReference, 'RWD-CAMEL');
    expect(claim.customerName, 'ลูกค้า Camel');
    expect(claim.status, RewardClaimStatus.approved);
    expect(claim.statusRaw, 'claim_approved');
    expect(claim.isPaid, isTrue);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_camel');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006123456789');
    expect(claim.walletName, 'Runtime Wallet');
    expect(claim.paidAt, '2026-07-01T11:00:00+07:00');
    expect(claim.adminNote, 'อนุมัติแล้ว');
    expect(claim.ticket?.id, 'ticket_camel');
    expect(claim.ticket?.number, '654321');
    expect(claim.prizeAmount, 3940);
    expect(claim.prizes.single.prizeType, 'back2');
    expect(claim.prizes.single.prizeNumber, '21');
    expect(rewardClaimDrawDateText(th, claim.ticket), '1 ก.ค. 2569');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีกรุงไทย');
    expect(
      rewardClaimPayoutChannelText(th, claim),
      'ธนาคารกรุงไทย\nx xxx6789',
    );
  });

  test('reward claim parser preserves production wrappers and ticket prizes',
      () {
    final claim = RewardClaimItem.fromJson({
      'customerName': 'ลูกค้า Wrapper',
      'ticketNumber': '987654',
      'gameName': 'งวดวันที่ 1 กรกฎาคม 2569',
      'ticket': {
        'id': 'ticket_wrapper',
        'rewardStatus': {
          'prizes': [
            {
              'rewardType': 'front3',
              'rewardNumber': '123',
              'rewardAmount': {'amount': 400000, 'currency': 'THB'},
            },
          ],
        },
      },
      'data': {
        'result': {
          'resource': {
            'claimId': 'rcl_wrapper',
            'claimReference': 'RWD-WRAP',
            'presentationStatus': 'claim_paid',
            'payout': {
              'method': 'bankTransfer',
              'ledgerId': 'ledger_wrapper',
              'bankAccount': {
                'bankDisplayName': 'ธนาคารกสิกรไทย',
                'bankDepositNo': '1234567890',
              },
            },
            'paidAt': '2026-07-01T11:00:00+07:00',
          },
        },
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(claim.id, 'rcl_wrapper');
    expect(claim.displayReference, 'RWD-WRAP');
    expect(claim.customerName, 'ลูกค้า Wrapper');
    expect(claim.status, RewardClaimStatus.paid);
    expect(claim.statusRaw, 'claim_paid');
    expect(claim.isPaid, isTrue);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_wrapper');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(claim.bankAccountNumber, '1234567890');
    expect(claim.ticket?.id, 'ticket_wrapper');
    expect(claim.ticket?.number, '987654');
    expect(claim.prizes.single.prizeType, 'front3');
    expect(claim.prizes.single.prizeNumber, '123');
    expect(claim.prizeAmount, 4000);
    expect(rewardClaimDrawDateText(th, claim.ticket), '1 ก.ค. 2569');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีกสิกรไทย');
  });

  test('reward claim parser accepts nested payout channel resources', () {
    final bankClaim = RewardClaimItem.fromJson({
      'id': 'rcl_bank_channel',
      'prize_amount': {'amount': 500000, 'currency': 'THB'},
      'payout': {
        'bankTransfer': {
          'status': 'transferred',
          'ledger': {'id': 'ledger_bank_channel'},
          'recipientBank': {
            'displayName': 'ธนาคารกรุงไทย',
            'accountNumber': '006123456789',
          },
          'transferredAt': '2026-07-01T12:00:00+07:00',
        },
      },
    });
    final walletClaim = RewardClaimItem.fromJson({
      'id': 'rcl_wallet_channel',
      'status': 'approved',
      'amount': {'amount': 120000, 'currency': 'THB'},
      'payout': {
        'walletCredit': {
          'ledgerId': 'ledger_wallet_channel',
          'destinationWallet': {'displayName': 'Runtime G-Wallet'},
          'paidAt': '2026-07-01T13:00:00+07:00',
        },
      },
    });
    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(bankClaim.status, RewardClaimStatus.paid);
    expect(bankClaim.isPaid, isTrue);
    expect(bankClaim.payoutMethod, 'bank_transfer');
    expect(bankClaim.payoutLedgerId, 'ledger_bank_channel');
    expect(bankClaim.bankName, 'ธนาคารกรุงไทย');
    expect(bankClaim.bankAccountNumber, '006123456789');
    expect(bankClaim.paidAt, '2026-07-01T12:00:00+07:00');
    expect(rewardClaimPayoutSummary(th, bankClaim), 'รับผ่านบัญชีกรุงไทย');
    expect(
      rewardClaimPayoutChannelText(th, bankClaim),
      'ธนาคารกรุงไทย\nx xxx6789',
    );

    expect(walletClaim.status, RewardClaimStatus.approved);
    expect(walletClaim.isPaid, isTrue);
    expect(walletClaim.payoutMethod, 'wallet_credit');
    expect(walletClaim.payoutLedgerId, 'ledger_wallet_channel');
    expect(walletClaim.walletName, 'Runtime G-Wallet');
    expect(walletClaim.paidAt, '2026-07-01T13:00:00+07:00');
    expect(
      rewardClaimPayoutSummary(th, walletClaim),
      'รับเข้า Runtime G-Wallet',
    );
  });

  test('reward claim parsers unwrap object scalar status and payout rows', () {
    final status = TicketRewardStatus.fromJson({
      'data': {
        'resource': {
          'rewardStatus': {
            'status': {'code': 'winning'},
            'canClaim': 'on',
            'claim': {
              'id': {'value': 'rcl_object_status'},
              'claimStatus': {'code': 'claim-rejected'},
              'payoutMethod': {'key': 'bank-transfer'},
              'adminNote': {'value': 'เอกสารไม่ผ่าน'},
              'rewardAmount': {'amount': 200000, 'currency': 'THB'},
            },
          },
        },
      },
    });
    final claim = RewardClaimItem.fromJson({
      'customerName': {'value': 'ลูกค้า Object'},
      'ticketNumber': {'value': '112233'},
      'claim': {
        'id': {'value': 'rcl_object_detail'},
        'claimStatus': {'code': 'pending-transfer'},
        'payoutMethod': {'key': 'bank-transfer'},
        'rewardAmount': {'amount': 500000, 'currency': 'THB'},
        'payout': {
          'bankTransfer': {
            'ledger': {
              'id': {'value': 'ledger_object'},
            },
            'recipientBank': {
              'displayName': {'value': 'ธนาคารกรุงไทย'},
              'accountNumber': {'value': '006123456789'},
            },
          },
        },
      },
    });
    final submission = RewardClaimSubmission.fromJson({
      'submission': {
        'claimId': {'value': 'rcl_object_submission'},
        'presentationStatus': {'code': 'claim-submitted'},
        'submittedAt': {'value': '2026-07-01T12:00:00+07:00'},
      },
    });

    expect(status.status, 'winning');
    expect(status.claimable, isTrue);
    expect(status.claimStatus, 'claim_rejected');
    expect(status.rewardClaimId, 'rcl_object_status');
    expect(status.payoutMethod, 'bank-transfer');
    expect(status.adminNote, 'เอกสารไม่ผ่าน');
    expect(status.prizeAmount, 2000);
    expect(claim.id, 'rcl_object_detail');
    expect(claim.customerName, 'ลูกค้า Object');
    expect(claim.ticket?.number, '112233');
    expect(claim.status, RewardClaimStatus.approved);
    expect(claim.statusRaw, 'pending-transfer');
    expect(claim.isPaid, isTrue);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_object');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006123456789');
    expect(claim.prizeAmount, 5000);
    expect(submission.id, 'rcl_object_submission');
    expect(submission.status, 'claim-submitted');
    expect(submission.createdAt, '2026-07-01T12:00:00+07:00');
  });

  test('reward claim page parser accepts legacy claims and pagination', () {
    final page = RewardClaimPage.fromJson({
      'result': {
        'claims': [
          {
            'id': 'rcl_legacy_page_1',
            'status': 'approved',
            'payout_method': 'wallet_credit',
            'wallet_name': 'Primary wallet',
          },
        ],
        'pagination': {
          'cursor': 'reward_claim_cursor_2',
          'has_more': 'yes',
        },
      },
    });
    final aliasPage = RewardClaimPage.fromJson({
      'result': {
        'reward_claims': [
          {
            'id': 'rcl_legacy_page_2',
            'status': 'cancelled',
            'payout_method': 'bank_transfer',
          },
        ],
        'pagination': {
          'next_cursor': 'reward_claim_cursor_3',
          'has_more': 1,
        },
      },
    });

    expect(page.items.single.id, 'rcl_legacy_page_1');
    expect(page.items.single.walletName, 'Primary wallet');
    expect(page.nextCursor, 'reward_claim_cursor_2');
    expect(page.hasMore, isTrue);
    expect(aliasPage.items.single.id, 'rcl_legacy_page_2');
    expect(aliasPage.items.single.status, RewardClaimStatus.cancelled);
    expect(aliasPage.nextCursor, 'reward_claim_cursor_3');
    expect(aliasPage.hasMore, isTrue);

    final camelPage = RewardClaimPage.fromJson({
      'data': {
        'rewardClaims': [
          {
            'claimId': 'rcl_camel_page',
            'claimStatus': 'claim_submitted',
          },
        ],
        'meta': {
          'nextCursor': 'reward_claim_cursor_4',
          'hasMore': true,
        },
      },
    });

    expect(camelPage.items.single.id, 'rcl_camel_page');
    expect(camelPage.items.single.status, RewardClaimStatus.submitted);
    expect(camelPage.nextCursor, 'reward_claim_cursor_4');
    expect(camelPage.hasMore, isTrue);

    final recursivePage = RewardClaimPage.fromJson({
      'meta': {'hasMore': true},
      'data': {
        'resource': {
          'rewardClaimPage': {
            'rewardClaims': [
              {
                'rewardClaim': {
                  'rewardClaimId': 'rcl_recursive_page',
                  'claimStatus': 'claim_paid',
                  'customerDisplayName': 'ลูกค้า Recursive',
                  'rewardAmount': {'amount': 99000, 'currency': 'THB'},
                },
              },
            ],
            'pagination': {
              'nextCursor': 'reward_claim_recursive_cursor',
            },
          },
        },
      },
    });

    expect(recursivePage.items.single.id, 'rcl_recursive_page');
    expect(recursivePage.items.single.status, RewardClaimStatus.paid);
    expect(recursivePage.items.single.customerName, 'ลูกค้า Recursive');
    expect(recursivePage.items.single.prizeAmount, 990);
    expect(recursivePage.nextCursor, 'reward_claim_recursive_cursor');
    expect(recursivePage.hasMore, isTrue);
  });

  test('claim status parsers accept Nuxt claim aliases', () {
    expect(
      RewardClaimStatus.fromApi('claim_submitted'),
      RewardClaimStatus.submitted,
    );
    expect(
      RewardClaimStatus.fromApi('claim_pending'),
      RewardClaimStatus.submitted,
    );
    expect(
      RewardClaimStatus.fromApi('pending_review'),
      RewardClaimStatus.submitted,
    );
    expect(
      RewardClaimStatus.fromApi('claim_approved'),
      RewardClaimStatus.approved,
    );
    expect(
      RewardClaimStatus.fromApi('pending_transfer'),
      RewardClaimStatus.approved,
    );
    expect(
      RewardClaimStatus.fromApi('pending-transfer'),
      RewardClaimStatus.approved,
    );
    expect(RewardClaimStatus.fromApi('claim_paid'), RewardClaimStatus.paid);
    expect(RewardClaimStatus.fromApi('claim-paid'), RewardClaimStatus.paid);
    expect(RewardClaimStatus.fromApi('transferred'), RewardClaimStatus.paid);
    expect(
      RewardClaimStatus.fromApi('payout_completed'),
      RewardClaimStatus.paid,
    );
    expect(
      RewardClaimStatus.fromApi('claim_rejected'),
      RewardClaimStatus.rejected,
    );
    expect(
      RewardClaimStatus.fromApi('claim-rejected'),
      RewardClaimStatus.rejected,
    );
    expect(
      RewardClaimStatus.fromApi('declined'),
      RewardClaimStatus.rejected,
    );
    expect(
      RewardClaimStatus.fromApi('claim_cancelled'),
      RewardClaimStatus.cancelled,
    );
    expect(
      RewardClaimStatus.fromApi('claim-cancelled'),
      RewardClaimStatus.cancelled,
    );
    expect(
      RewardClaimStatus.fromApi(' claim_paid '),
      RewardClaimStatus.paid,
    );
    expect(
      ActivityClaimStatus.fromApi('claim_submitted'),
      ActivityClaimStatus.submitted,
    );
    expect(
      ActivityClaimStatus.fromApi('in_review'),
      ActivityClaimStatus.submitted,
    );
    expect(
      ActivityClaimStatus.fromApi('claim_approved'),
      ActivityClaimStatus.approved,
    );
    expect(
      ActivityClaimStatus.fromApi('waiting_transfer'),
      ActivityClaimStatus.approved,
    );
    expect(ActivityClaimStatus.fromApi('claim_paid'), ActivityClaimStatus.paid);
    expect(ActivityClaimStatus.fromApi('success'), ActivityClaimStatus.paid);
    expect(
      ActivityClaimStatus.fromApi('claim_rejected'),
      ActivityClaimStatus.rejected,
    );
    expect(
      ActivityClaimStatus.fromApi('declined'),
      ActivityClaimStatus.rejected,
    );
    expect(
      ActivityClaimStatus.fromApi('claim_canceled'),
      ActivityClaimStatus.cancelled,
    );
    expect(
      ActivityClaimStatus.fromApi(' claim_rejected '),
      ActivityClaimStatus.rejected,
    );
  });

  test('activity claim maps award, payout, status, and baht amount', () {
    final claim = ActivityClaimItem.fromJson({
      'id': 'acl_1',
      'reference': 'ACT-0001',
      'status': 'approved',
      'payout_method': 'bank_transfer',
      'claim_amount': {'amount': 200000, 'currency': 'THB'},
      'bank_account': {
        'bank_name': 'ธนาคารกสิกรไทย',
        'account_number': '1234567890',
      },
      'customer': {'name': 'มานะ ใจดี'},
      'activity_name': 'ทายเลขประจำงวด',
      'award': {
        'type': 'lucky_board',
        'prediction_type': 'first_prize_last2',
        'amount': {'amount': 200000, 'currency': 'THB'},
      },
    });

    expect(claim.amount, 2000);
    expect(claim.isPaid, isFalse);
    expect(claim.status, ActivityClaimStatus.approved);
    expect(claim.type, 'lucky_board');
    expect(claim.predictionType, 'first_prize_last2');
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(maskActivityBankAccount(claim.bankAccountNumber), 'x xxx7890');
  });

  testWidgets('activity claim maps payout ledger and bank variants',
      (tester) async {
    final claim = ActivityClaimItem.fromJson({
      'id': 'acl_legacy',
      'reference': 'ACT-LEGACY',
      'status': 'approved',
      'payout_ledger_id': 'ledger_activity_1',
      'payout_method': 'bank_transfer',
      'claim_amount': 1500,
      'customer_name': 'ลูกค้ากิจกรรม Legacy',
      'bank_name': 'ธนาคารกสิกรไทย',
      'bank_account_number': '123-456-7890',
      'wallet_name': 'Primary wallet',
      'activity_name': 'ลุ้นโชคงวดนี้',
      'award': {
        'type': 'cashback',
        'amount': 1500,
      },
    });

    var status = '';
    var summary = '';
    var channel = '';
    await tester.pumpWidget(
      Localizations(
        locale: fallbackCustomerLocale,
        delegates: const [
          CustomerLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            status = localizedActivityClaimStatusLabel(context, claim);
            summary = localizedActivityClaimPayoutSummary(context, claim);
            channel = localizedActivityClaimPayoutChannel(context, claim);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(claim.isPaid, isTrue);
    expect(claim.customerName, 'ลูกค้ากิจกรรม Legacy');
    expect(claim.payoutLedgerId, 'ledger_activity_1');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(claim.bankAccountNumber, '123-456-7890');
    expect(status, 'โอนเงินสำเร็จ');
    expect(summary, 'รับผ่านบัญชีกสิกรไทย');
    expect(channel, 'ธนาคารกสิกรไทย\nx xxx7890');
  });

  testWidgets('activity claim maps wrapped award and payout aliases',
      (tester) async {
    final claim = ActivityClaimItem.fromJson({
      'customer_full_name': 'ลูกค้ากิจกรรม Wrapped',
      'activity': {'name': 'ลุ้นโชคงวดใหญ่'},
      'payout': {
        'ledger_id': 'ledger_activity_wrapped',
        'wallet': {'name': 'Primary wallet'},
      },
      'activity_award': {
        'id': 'award_wrapped',
        'award_type': 'cashback',
        'reward_amount': {'amount': 88000, 'currency': 'THB'},
      },
      'activity_claim': {
        'id': 'acl_wrapped',
        'claim_status': 'claim_approved',
        'payout_type': 'wallet',
        'claimed_at': '2026-07-01T11:00:00+07:00',
      },
    });

    var status = '';
    var summary = '';
    var rewardLabel = '';
    await tester.pumpWidget(
      Localizations(
        locale: fallbackCustomerLocale,
        delegates: const [
          CustomerLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            status = localizedActivityClaimStatusLabel(context, claim);
            summary = localizedActivityClaimPayoutSummary(context, claim);
            rewardLabel = localizedActivityClaimRewardLabel(context, claim);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(claim.id, 'acl_wrapped');
    expect(claim.status, ActivityClaimStatus.approved);
    expect(claim.statusRaw, 'claim_approved');
    expect(claim.isPaid, isTrue);
    expect(claim.customerName, 'ลูกค้ากิจกรรม Wrapped');
    expect(claim.activityName, 'ลุ้นโชคงวดใหญ่');
    expect(claim.award?.id, 'award_wrapped');
    expect(claim.type, 'cashback');
    expect(claim.amount, 880);
    expect(claim.payoutMethod, 'wallet_credit');
    expect(claim.payoutLedgerId, 'ledger_activity_wrapped');
    expect(status, 'โอนเงินสำเร็จ');
    expect(summary, 'รับเข้า Primary wallet');
    expect(rewardLabel, 'เงินคืนกิจกรรม');
  });

  testWidgets('activity claim parser accepts camelCase detail aliases',
      (tester) async {
    final claim = ActivityClaimItem.fromJson({
      'activityAwardId': 'award_camel',
      'activityName': 'ภารกิจ Camel',
      'claim': {
        'claimId': 'acl_camel',
        'claimReference': 'ACT-CAMEL',
        'claimStatus': 'claim_approved',
        'payoutMethod': 'bankTransfer',
        'payoutLedgerId': 'ledger_activity_camel',
        'customerName': 'ลูกค้ากิจกรรม Camel',
        'bankName': 'ธนาคารกสิกรไทย',
        'bankAccountNumber': '1234567890',
        'walletName': 'Runtime Wallet',
        'paidAt': '2026-07-01T11:00:00+07:00',
        'createdAt': '2026-07-01T10:00:00+07:00',
        'customerNote': 'ลูกค้าแนบข้อมูลครบ',
        'adminNote': 'อนุมัติแล้ว',
        'awardType': 'cashback',
        'predictionType': 'last_two_digits',
        'awardAmount': {'amount': 88000, 'currency': 'THB'},
      },
    });

    var status = '';
    var summary = '';
    var channel = '';
    var rewardLabel = '';
    await tester.pumpWidget(
      Localizations(
        locale: fallbackCustomerLocale,
        delegates: const [
          CustomerLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            status = localizedActivityClaimStatusLabel(context, claim);
            summary = localizedActivityClaimPayoutSummary(context, claim);
            channel = localizedActivityClaimPayoutChannel(context, claim);
            rewardLabel = localizedActivityClaimRewardLabel(context, claim);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(claim.id, 'acl_camel');
    expect(claim.displayReference, 'ACT-CAMEL');
    expect(claim.customerName, 'ลูกค้ากิจกรรม Camel');
    expect(claim.activityName, 'ภารกิจ Camel');
    expect(claim.award?.id, 'award_camel');
    expect(claim.type, 'cashback');
    expect(claim.predictionType, 'last_two_digits');
    expect(claim.amount, 880);
    expect(claim.status, ActivityClaimStatus.approved);
    expect(claim.statusRaw, 'claim_approved');
    expect(claim.isPaid, isTrue);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_activity_camel');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(claim.bankAccountNumber, '1234567890');
    expect(claim.walletName, 'Runtime Wallet');
    expect(claim.paidAt, '2026-07-01T11:00:00+07:00');
    expect(claim.createdAt, '2026-07-01T10:00:00+07:00');
    expect(claim.customerNote, 'ลูกค้าแนบข้อมูลครบ');
    expect(claim.adminNote, 'อนุมัติแล้ว');
    expect(status, 'โอนเงินสำเร็จ');
    expect(summary, 'รับผ่านบัญชีกสิกรไทย');
    expect(channel, 'ธนาคารกสิกรไทย\nx xxx7890');
    expect(rewardLabel, 'เงินคืนกิจกรรม');
  });

  testWidgets('activity claim parser preserves production wrappers',
      (tester) async {
    final claim = ActivityClaimItem.fromJson({
      'customerDisplayName': 'ลูกค้ากิจกรรม Wrapper',
      'activityName': 'ภารกิจ Wrapper',
      'award': {
        'activityAwardId': 'award_wrapper',
        'activityName': 'ภารกิจ Wrapper',
        'rewardType': 'cashback',
        'rewardAmount': {'amount': 99000, 'currency': 'THB'},
      },
      'data': {
        'result': {
          'resource': {
            'activityClaimId': 'acl_wrapper',
            'claimReference': 'ACT-WRAP',
            'presentationStatus': 'claim_paid',
            'payout': {
              'method': 'bankTransfer',
              'ledgerId': 'ledger_activity_wrapper',
              'bankAccount': {
                'bankDisplayName': 'ธนาคารกรุงไทย',
                'bankDepositNo': '006123456789',
              },
            },
            'paidAt': '2026-07-01T11:00:00+07:00',
          },
        },
      },
    });

    var status = '';
    var summary = '';
    var channel = '';
    var rewardLabel = '';
    await tester.pumpWidget(
      Localizations(
        locale: fallbackCustomerLocale,
        delegates: const [
          CustomerLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            status = localizedActivityClaimStatusLabel(context, claim);
            summary = localizedActivityClaimPayoutSummary(context, claim);
            channel = localizedActivityClaimPayoutChannel(context, claim);
            rewardLabel = localizedActivityClaimRewardLabel(context, claim);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(claim.id, 'acl_wrapper');
    expect(claim.displayReference, 'ACT-WRAP');
    expect(claim.customerName, 'ลูกค้ากิจกรรม Wrapper');
    expect(claim.activityName, 'ภารกิจ Wrapper');
    expect(claim.award?.id, 'award_wrapper');
    expect(claim.type, 'cashback');
    expect(claim.amount, 990);
    expect(claim.status, ActivityClaimStatus.paid);
    expect(claim.statusRaw, 'claim_paid');
    expect(claim.isPaid, isTrue);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_activity_wrapper');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006123456789');
    expect(status, 'โอนเงินสำเร็จ');
    expect(summary, 'รับผ่านบัญชีกรุงไทย');
    expect(channel, 'ธนาคารกรุงไทย\nx xxx6789');
    expect(rewardLabel, 'เงินคืนกิจกรรม');
  });

  testWidgets('activity claim parser accepts nested payout channel resources',
      (tester) async {
    final bankClaim = ActivityClaimItem.fromJson({
      'id': 'acl_bank_channel',
      'claim_amount': {'amount': 250000, 'currency': 'THB'},
      'activity_name': 'ภารกิจ Bank Channel',
      'payout': {
        'bankTransfer': {
          'status': 'transferred',
          'ledger': {'id': 'ledger_activity_bank_channel'},
          'recipientBank': {
            'displayName': 'ธนาคารกรุงไทย',
            'accountNumber': '006123456789',
          },
          'transferredAt': '2026-07-01T12:00:00+07:00',
        },
      },
    });
    final walletClaim = ActivityClaimItem.fromJson({
      'id': 'acl_wallet_channel',
      'status': 'approved',
      'claim_amount': {'amount': 99000, 'currency': 'THB'},
      'activity_name': 'ภารกิจ Wallet Channel',
      'payout': {
        'walletCredit': {
          'ledgerId': 'ledger_activity_wallet_channel',
          'destinationWallet': {'displayName': 'Runtime G-Wallet'},
          'paidAt': '2026-07-01T13:00:00+07:00',
        },
      },
    });

    var bankStatus = '';
    var bankSummary = '';
    var bankChannel = '';
    var walletStatus = '';
    var walletSummary = '';
    await tester.pumpWidget(
      Localizations(
        locale: fallbackCustomerLocale,
        delegates: const [
          CustomerLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            bankStatus = localizedActivityClaimStatusLabel(context, bankClaim);
            bankSummary =
                localizedActivityClaimPayoutSummary(context, bankClaim);
            bankChannel =
                localizedActivityClaimPayoutChannel(context, bankClaim);
            walletStatus =
                localizedActivityClaimStatusLabel(context, walletClaim);
            walletSummary =
                localizedActivityClaimPayoutSummary(context, walletClaim);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(bankClaim.status, ActivityClaimStatus.paid);
    expect(bankClaim.isPaid, isTrue);
    expect(bankClaim.payoutMethod, 'bank_transfer');
    expect(bankClaim.payoutLedgerId, 'ledger_activity_bank_channel');
    expect(bankClaim.bankName, 'ธนาคารกรุงไทย');
    expect(bankClaim.bankAccountNumber, '006123456789');
    expect(bankClaim.paidAt, '2026-07-01T12:00:00+07:00');
    expect(bankStatus, 'โอนเงินสำเร็จ');
    expect(bankSummary, 'รับผ่านบัญชีกรุงไทย');
    expect(bankChannel, 'ธนาคารกรุงไทย\nx xxx6789');

    expect(walletClaim.status, ActivityClaimStatus.approved);
    expect(walletClaim.isPaid, isTrue);
    expect(walletClaim.payoutMethod, 'wallet_credit');
    expect(walletClaim.payoutLedgerId, 'ledger_activity_wallet_channel');
    expect(walletClaim.walletName, 'Runtime G-Wallet');
    expect(walletClaim.paidAt, '2026-07-01T13:00:00+07:00');
    expect(walletStatus, 'โอนเงินสำเร็จ');
    expect(walletSummary, 'รับเข้า Runtime G-Wallet');
  });

  test('activity claim page parser accepts legacy claims and pagination', () {
    final page = ActivityClaimPage.fromJson({
      'result': {
        'activity_claims': [
          {
            'id': 'acl_legacy_page_1',
            'status': 'approved',
            'payout_method': 'wallet_credit',
            'wallet_name': 'Primary wallet',
            'activity_name': 'ลุ้นโชคทุกงวด',
          },
        ],
        'pagination': {
          'cursor': 'activity_claim_cursor_2',
          'has_more': 'yes',
        },
      },
    });
    final aliasPage = ActivityClaimPage.fromJson({
      'result': {
        'claims': [
          {
            'id': 'acl_legacy_page_2',
            'status': 'cancelled',
            'payout_method': 'bank_transfer',
            'activity_name': 'ลุ้นเลขท้าย',
          },
        ],
        'pagination': {
          'next_cursor': 'activity_claim_cursor_3',
          'has_more': 1,
        },
      },
    });

    expect(page.items.single.id, 'acl_legacy_page_1');
    expect(page.items.single.walletName, 'Primary wallet');
    expect(page.items.single.activityName, 'ลุ้นโชคทุกงวด');
    expect(page.nextCursor, 'activity_claim_cursor_2');
    expect(page.hasMore, isTrue);
    expect(aliasPage.items.single.id, 'acl_legacy_page_2');
    expect(aliasPage.items.single.status, ActivityClaimStatus.cancelled);
    expect(aliasPage.nextCursor, 'activity_claim_cursor_3');
    expect(aliasPage.hasMore, isTrue);

    final camelPage = ActivityClaimPage.fromJson({
      'data': {
        'activityClaims': [
          {
            'activityClaimId': 'acl_camel_page',
            'claimStatus': 'claim_submitted',
          },
        ],
        'meta': {
          'nextCursor': 'activity_claim_cursor_4',
          'hasMore': true,
        },
      },
    });

    expect(camelPage.items.single.id, 'acl_camel_page');
    expect(camelPage.items.single.status, ActivityClaimStatus.submitted);
    expect(camelPage.nextCursor, 'activity_claim_cursor_4');
    expect(camelPage.hasMore, isTrue);

    final recursivePage = ActivityClaimPage.fromJson({
      'meta': {'hasMore': true},
      'data': {
        'resource': {
          'activityClaimPage': {
            'activityClaims': [
              {
                'activityClaim': {
                  'activityClaimId': 'acl_recursive_page',
                  'claimStatus': 'claim_paid',
                  'activityName': 'กิจกรรม Recursive',
                  'claimAmount': {'amount': 77000, 'currency': 'THB'},
                },
              },
            ],
            'pagination': {
              'nextCursor': 'activity_claim_recursive_cursor',
            },
          },
        },
      },
    });

    expect(recursivePage.items.single.id, 'acl_recursive_page');
    expect(recursivePage.items.single.status, ActivityClaimStatus.paid);
    expect(recursivePage.items.single.activityName, 'กิจกรรม Recursive');
    expect(recursivePage.items.single.amount, 770);
    expect(recursivePage.nextCursor, 'activity_claim_recursive_cursor');
    expect(recursivePage.hasMore, isTrue);

    final productionPage = ActivityClaimPage.fromJson({
      'meta': {'hasMore': true},
      'data': {
        'resource': {
          'activityClaimsPage': {
            'claims': [
              {
                'activityClaim': {
                  'activityClaimId': 'acl_activity_claims_page',
                  'presentationStatus': 'pending-transfer',
                  'activityName': 'กิจกรรม Page Alias',
                  'claimAmount': {'amount': 88000, 'currency': 'THB'},
                },
              },
            ],
            'pagination': {
              'nextCursor': 'activity_claim_alias_cursor',
            },
          },
        },
      },
    });
    final claimsPage = ActivityClaimPage.fromJson({
      'data': {
        'resource': {
          'claimsPage': {
            'items': [
              {
                'claimId': 'acl_claims_page',
                'claimStatus': 'claim-paid',
              },
            ],
            'meta': {
              'nextCursor': 'claims_page_cursor',
              'hasMore': true,
            },
          },
        },
      },
    });

    expect(productionPage.items.single.id, 'acl_activity_claims_page');
    expect(productionPage.items.single.status, ActivityClaimStatus.approved);
    expect(productionPage.items.single.activityName, 'กิจกรรม Page Alias');
    expect(productionPage.items.single.amount, 880);
    expect(productionPage.nextCursor, 'activity_claim_alias_cursor');
    expect(productionPage.hasMore, isTrue);
    expect(claimsPage.items.single.id, 'acl_claims_page');
    expect(claimsPage.items.single.status, ActivityClaimStatus.paid);
    expect(claimsPage.nextCursor, 'claims_page_cursor');
    expect(claimsPage.hasMore, isTrue);
  });

  testWidgets('activity claim dates use active customer locale',
      (tester) async {
    final claim = ActivityClaimItem.fromJson({
      'id': 'acl_2',
      'status': 'paid',
      'claim_amount': {'amount': 10000, 'currency': 'THB'},
      'created_at': '2026-06-26T10:15:00+07:00',
      'submitted_at': '2026-06-26T10:15:00+07:00',
    });

    Future<String> renderWith(Locale locale) async {
      var output = '';
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [
            CustomerLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              output = localizedActivityClaimSubmittedAt(context, claim);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      return output;
    }

    final thai = await renderWith(fallbackCustomerLocale);
    final english = await renderWith(const Locale('en', 'US'));

    expect(
      thai,
      formatLocalizedDateTime(claim.submittedAt, 'th-TH'),
    );
    expect(
      english,
      formatLocalizedDateTime(claim.submittedAt, 'en-US'),
    );
    expect(thai, isNot(english));
  });

  test('customer profile settings maps bank and auto reward config', () {
    final profile = CustomerProfileSettings.fromJson({
      'id': 'cus_1',
      'member_no': 'CUS00655551234',
      'name': 'ดีทู',
      'phone': '0812345678',
      'primary_wallet': {
        'id': 'wallet_55551234',
        'name': 'กระเป๋าร้านดีทีม',
      },
      'reward_payout_bank_account': {
        'bank_name': 'ธนาคารกรุงไทย',
        'account_name': 'ดีทู',
        'account_number': '006123456789',
      },
      'auto_reward_claim': {
        'enabled': true,
        'type': 'bank_transfer',
        'payout_method': 'bank_transfer',
      },
    });

    expect(profile.customerNo, 'CUS00655551234');
    expect(profile.walletId, 'wallet_55551234');
    expect(profile.walletName, 'กระเป๋าร้านดีทีม');
    expect(profile.bankAccount.isComplete, isTrue);
    expect(profile.bankAccount.maskedNumber, '********6789');
    expect(profile.autoReward.enabled, isTrue);
    expect(profile.autoReward.isBankTransfer, isTrue);
    expect(maskWalletId(profile.walletId), '006 XXXXXXXX 1234');
    expect(maskWalletId('wallet_without_digits'), '-');
  });

  test('customer profile settings accepts wrapped camelCase payload aliases',
      () {
    final profile = CustomerProfileSettings.fromJson({
      'data': {
        'resource': {
          'profile': {
            'customerId': 'cus_9',
            'fullName': 'ดีทู โปรไฟล์',
            'customerNo': 'CUS-CAMEL',
            'phoneNumber': '0891112222',
            'primaryWallet': {
              'walletId': 'wallet_7890',
              'displayName': 'Runtime Blue Wallet',
            },
            'bankAccount': {
              'bank': {'displayName': 'ธนาคารกรุงไทย'},
              'accountName': 'ดีทู โปรไฟล์',
              'bankAccountNumber': '006-123-456-789',
            },
            'autoRewardClaim': {
              'status': 'active',
              'payoutMethod': 'bank_transfer',
            },
          },
        },
      },
    });

    expect(profile.id, 'cus_9');
    expect(profile.name, 'ดีทู โปรไฟล์');
    expect(profile.customerNo, 'CUS-CAMEL');
    expect(profile.phone, '0891112222');
    expect(profile.walletId, 'wallet_7890');
    expect(profile.walletName, 'Runtime Blue Wallet');
    expect(profile.bankAccount.bankName, 'ธนาคารกรุงไทย');
    expect(profile.bankAccount.accountName, 'ดีทู โปรไฟล์');
    expect(profile.bankAccount.accountNumber, '006123456789');
    expect(profile.bankAccount.maskedNumber, '********6789');
    expect(profile.autoReward.enabled, isTrue);
    expect(profile.autoReward.isBankTransfer, isTrue);
  });

  test('line notification settings maps identity and OA state', () {
    final settings = LineNotificationSettings.fromJson({
      'line_available': true,
      'bot_display_name': 'DeeTeam',
      'add_friend_url': 'https://line.me/R/ti/p/@demo',
      'identity': {
        'id': 'line_1',
        'display_name': 'ดีทู',
        'picture_url': 'https://example.com/avatar.jpg',
        'friend_flag': true,
        'notification_enabled': true,
      },
    });

    expect(settings.lineAvailable, isTrue);
    expect(settings.isConnected, isTrue);
    expect(settings.identity?.displayName, 'ดีทู');
    expect(settings.identity?.friendFlag, isTrue);
  });

  test('purchase history order maps ticket count, money, and payment details',
      () {
    final order = PurchaseHistoryOrder.fromJson({
      'id': 'ord_1',
      'reference': '27979793562404561777356240',
      'payment_method': 'wallet',
      'total': {'amount': 8000, 'currency': 'THB'},
      'ticket_count': 1,
      'game': {'name': 'งวดวันที่ 2 พฤษภาคม 2569'},
      'wallet': {'name': 'G Wallet'},
      'payment': {'provider_reference': '0061234567891244'},
      'paid_at': '2026-04-28T13:04:00+07:00',
      'tickets': [
        {'id': 'ticket_1', 'full_number': '415206'},
      ],
    });

    expect(order.total, 80);
    expect(order.ticketCount, 1);
    expect(order.gameName, 'งวดวันที่ 2 พฤษภาคม 2569');
    expect(order.paymentMethod, 'wallet');
    expect(order.maskedPaymentReference, '006 XXXXXXXXX 1244');
    expect(order.tickets.single.number, '415206');
  });

  test('purchase history order accepts Nuxt-style lotteries fallback', () {
    final order = PurchaseHistoryOrder.fromJson({
      'id': 'ord_lotteries',
      'reference': 'ORD-LOTTERIES',
      'payment_method': 'wallet',
      'total': 240,
      'game': {'name': 'งวดวันที่ 1 กรกฎาคม 2569'},
      'wallet': {'name': 'G Wallet'},
      'lotteries': [
        {'id': 'ticket_1', 'number': '415206', 'count': 2},
        {'id': 'ticket_2', 'lottery_number': '273707'},
      ],
    });

    expect(order.total, 240);
    expect(order.ticketCount, 3);
    expect(order.tickets.map((ticket) => ticket.number), [
      '415206',
      '273707',
    ]);
    expect(order.displayReference, 'ORD-LOTTERIES');
  });

  test('purchase history order accepts Nuxt-style receipt composite payload',
      () {
    final order = PurchaseHistoryOrder.fromJson({
      'order': {
        'id': 'ord_receipt',
        'status': 'paid',
        'payment_status': 'paid',
        'payment_method': 'wallet',
        'store': {'name': 'ร้านดีทีม'},
        'game': {'draw_at': '2026-07-01T16:00:00+07:00'},
        'lotteries': [
          {
            'id': 'ticket_1',
            'number': '415206',
            'count': 2,
            'game': {'name': 'งวดจาก ticket ที่ไม่ควรชนะ'},
          },
        ],
        'updated_at': '2026-06-29T12:15:00+07:00',
      },
      'game': {'name': 'งวดวันที่ 1 กรกฎาคม 2569'},
      'wallet': {'name': 'G Wallet'},
      'count': 2,
      'total': 160,
      'reference': 'ORD-RECEIPT',
      'paid_at': '2026-06-30T13:04:00+07:00',
    });

    expect(order.id, 'ord_receipt');
    expect(order.reference, 'ORD-RECEIPT');
    expect(order.total, 160);
    expect(order.ticketCount, 2);
    expect(order.gameName, 'งวดวันที่ 1 กรกฎาคม 2569');
    expect(order.drawAt, '2026-07-01T16:00:00+07:00');
    expect(order.walletName, 'G Wallet');
    expect(order.storeName, 'ร้านดีทีม');
    expect(order.paidAt, '2026-06-30T13:04:00+07:00');
    expect(order.tickets.single.number, '415206');
  });

  test('purchase history order accepts checkout-style aliases', () {
    final order = PurchaseHistoryOrder.fromJson({
      'checkout_order': {
        'order_id': 'ord_alias',
        'status': 'pending_payment',
        'paymentStatus': 'pending_payment',
        'paymentMethod': 'external_payment',
        'price': {'amount': 16000, 'currency': 'THB'},
        'ticketCount': '2',
        'payment': {
          'status': 'pending_payment',
          'method': 'external_payment',
          'provider_reference': 'PAY-ALIAS',
        },
        'lotteries': [
          {'id': 'ticket_alias_1', 'number': '123456'},
          {'id': 'ticket_alias_2', 'lottery_number': '654321'},
        ],
      },
      'orderReference': 'ORD-ALIAS',
      'wallet_name': 'Runtime Wallet',
      'store_name': 'ร้าน alias',
      'payment': {
        'provider': 'runtime_provider',
        'redirectUrl': 'https://pay.example.test/session/ord_alias',
      },
      'paidAt': '2026-07-01T13:04:00+07:00',
    });

    expect(order.id, 'ord_alias');
    expect(order.reference, 'ORD-ALIAS');
    expect(order.paymentStatus, 'pending_payment');
    expect(order.paymentMethod, 'external_payment');
    expect(order.total, 160);
    expect(order.ticketCount, 2);
    expect(order.walletName, 'Runtime Wallet');
    expect(order.storeName, 'ร้าน alias');
    expect(order.paymentProvider, 'runtime_provider');
    expect(order.paymentReference, 'PAY-ALIAS');
    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_alias'),
    );
    expect(order.paidAt, '2026-07-01T13:04:00+07:00');
    expect(order.tickets.map((ticket) => ticket.number), [
      '123456',
      '654321',
    ]);
  });

  test('purchase history order accepts receipt wrapped checkoutOrder aliases',
      () {
    final order = PurchaseHistoryOrder.fromJson({
      'data': {
        'receipt': {
          'checkoutOrder': {
            'orderId': 'ord_receipt_alias',
            'status': 'paid',
            'paymentStatus': 'paid',
            'paymentMethod': 'external_payment',
            'amount': {'amount': 24000, 'currency': 'THB'},
            'item_count': '3',
            'orderItems': [
              {'id': 'ticket_receipt_1', 'number': '111111', 'count': 2},
              {'id': 'ticket_receipt_2', 'lottery_number': '222222'},
            ],
            'payment': {
              'provider': 'runtime_gateway',
              'providerReference': '0069876543219999',
              'paidAt': '2026-07-01T13:04:00+07:00',
            },
          },
          'referenceCode': 'ORD-RECEIPT-ALIAS',
          'walletName': 'Runtime Wallet',
          'storeName': 'ร้าน receipt alias',
          'game': {
            'name': 'งวดวันที่ 1 กรกฎาคม 2569',
            'draw_at': '2026-07-01T16:00:00+07:00',
          },
        },
      },
    });

    expect(order.id, 'ord_receipt_alias');
    expect(order.reference, 'ORD-RECEIPT-ALIAS');
    expect(order.paymentStatus, 'paid');
    expect(order.paymentMethod, 'external_payment');
    expect(order.total, 240);
    expect(order.ticketCount, 3);
    expect(order.walletName, 'Runtime Wallet');
    expect(order.storeName, 'ร้าน receipt alias');
    expect(order.gameName, 'งวดวันที่ 1 กรกฎาคม 2569');
    expect(order.drawAt, '2026-07-01T16:00:00+07:00');
    expect(order.paymentProvider, 'runtime_gateway');
    expect(order.paymentReference, '0069876543219999');
    expect(order.paidAt, '2026-07-01T13:04:00+07:00');
    expect(order.maskedPaymentReference, '006 XXXXXXXXX 9999');
    expect(order.tickets.map((ticket) => ticket.number), [
      '111111',
      '222222',
    ]);
  });

  test('purchase history order maps safe external payment redirect URI', () {
    final order = PurchaseHistoryOrder.fromJson({
      'id': 'ord_pending',
      'payment_method': 'external_payment',
      'payment_status': 'pending_payment',
      'total': {'amount': 8000, 'currency': 'THB'},
      'payment': {
        'redirect_url': 'https://pay.example.test/session/ord_pending',
      },
    });
    final providerWrapped = PurchaseHistoryOrder.fromJson({
      'receipt': {
        'checkoutOrder': {
          'id': 'ord_pending_links',
          'payment_method': 'external_payment',
          'payment_status': 'pending_payment',
          'total': {'amount': 8000, 'currency': 'THB'},
        },
        'paymentSession': {
          'links': {
            'checkout': {
              'href': 'https://pay.example.test/session/ord_pending_links',
            },
          },
        },
      },
    });
    final unsafe = PurchaseHistoryOrder.fromJson({
      'id': 'ord_unsafe',
      'payment_method': 'external_payment',
      'redirect_url': 'javascript:alert(1)',
    });

    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_pending'),
    );
    expect(
      providerWrapped.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_pending_links'),
    );
    expect(unsafe.redirectUri, isNull);
  });

  test('reward result maps prize groups and fills unresolved placeholders', () {
    final result = RewardResultGame.fromPublicSummary({
      'game_id': 'game_1',
      'game_name': 'งวดวันที่ 1 ก.ค. 2569',
      'status': 'live_unconfirmed',
      'official_status': 'draft',
      'completion_percent': 45,
      'prizes': [
        {
          'prize_type': 'first_prize',
          'prize_number': '287184',
          'amount': {'amount': 600000000, 'currency': 'THB'},
        },
        {
          'prize_type': 'back2',
          'prize_number': 'pending_back2',
          'amount': {'amount': 200000, 'currency': 'THB'},
        },
        {
          'prize_type': 'front3',
          'prize_number': '434',
          'amount': {'amount': 400000, 'currency': 'THB'},
        },
      ],
    });

    expect(result.isUnofficial, isTrue);
    expect(result.completionPercent, 45);
    expect(result.summary.first, '287184');
    expect(result.summary.last2, 'xx');
    expect(result.summary.front3, ['434', 'xxx']);
    expect(result.hasResolvedResult, isTrue);
    expect(result.reward('reward_1')?.amount, 6000000);
  });

  test('reward result parser accepts recursive camelCase production wrappers',
      () {
    final result = RewardResultGame.fromPublicSummary({
      'data': {
        'resource': {
          'rewardResult': {
            'game': {
              'id': {'value': 'game_wrapped'},
              'drawLabel': 'งวดวันที่ 16 ก.ค. 2569',
              'drawAt': {'value': '2026-07-16T16:00:00+07:00'},
            },
            'resultStatus': {'code': 'live_unconfirmed'},
            'officialStatus': {'value': 'draft'},
            'completionPercent': {'percent': '75%'},
            'rewardItems': [
              {
                'prizeType': {'code': 'first-prize'},
                'prizeNumbers': [
                  {'value': '751495'},
                ],
                'prizeAmount': {
                  'amount': 600000000,
                  'currency': 'THB',
                },
              },
              {
                'rewardType': 'front-3',
                'winningNumbers': [
                  '001',
                  {'number': '980'},
                ],
              },
              {
                'rewardType': 'last_2',
                'winningNumber': {'value': '62'},
              },
            ],
          },
        },
      },
    });

    expect(result.id, 'game_wrapped');
    expect(result.name, 'งวดวันที่ 16 ก.ค. 2569');
    expect(result.drawAt, '2026-07-16T16:00:00+07:00');
    expect(result.resultStatus, 'live_unconfirmed');
    expect(result.officialStatus, 'draft');
    expect(result.completionPercent, 75);
    expect(result.summary.first, '751495');
    expect(result.summary.front3, ['001', '980']);
    expect(result.summary.last2, '62');
    expect(result.reward('reward_1')?.amount, 6000000);
  });

  test('biometric device parser maps platform, status, and timestamps', () {
    final device = BiometricDevice.fromJson({
      'id': 'cbd_1',
      'device_id': 'device-1',
      'platform': 'ios',
      'device_name': '',
      'algorithm': 'ES256',
      'status': 'active',
      'registered_at': '2026-06-25T10:00:00+07:00',
      'last_used_at': null,
    });

    expect(device.platform, 'ios');
    expect(device.deviceName, isEmpty);
    expect(device.status, 'active');
    expect(device.isActive, isTrue);
    expect(device.lastUsedAt, isEmpty);
  });

  test('asset url resolver expands relative storage paths from api origin', () {
    const resolver = AssetUrlResolver(
      AppConfig(
        apiBaseUrl: 'https://shop.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
    );

    expect(
      resolver('/storage/news/full.webp'),
      'https://shop.example.com/storage/news/full.webp',
    );
    expect(
      resolver('https://cdn.example.com/file.webp'),
      'https://cdn.example.com/file.webp',
    );
    expect(
      resolver('news/full.webp'),
      'https://shop.example.com/upload/news/full.webp',
    );
  });

  test('asset url resolver prefers runtime CDN without changing full URLs', () {
    const resolver = AssetUrlResolver(
      AppConfig(
        apiBaseUrl: 'https://api.shop.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      assetCdnBaseUrl: 'https://cdn.shop.example.com/customer-assets',
    );

    expect(
      resolver('/storage/news/full.webp'),
      'https://cdn.shop.example.com/customer-assets/storage/news/full.webp',
    );
    expect(
      resolver('news/full.webp'),
      'https://cdn.shop.example.com/customer-assets/upload/news/full.webp',
    );
    expect(
      resolver('https://external.example.com/file.webp'),
      'https://external.example.com/file.webp',
    );
  });

  test('customer deep link normalizes universal social callbacks', () {
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/social/google/callback?code=a&state=b',
        ),
      ),
      '/social/google/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/social/apple/callback?code=a&state=b',
        ),
      ),
      '/social/apple/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('https://shop.example.com/line/callback?code=a&state=b'),
      ),
      '/line/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('https://shop.example.com/line/callback?code=a&state=b'),
        allowedHosts: const ['shop.example.com'],
      ),
      '/line/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('https://evil.example.net/line/callback?code=a&state=b'),
        allowedHosts: const ['shop.example.com'],
      ),
      isNull,
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/social/google/callback#authorizationCode=fragment-code&callbackState=fragment-state&redirect=%2Fcheckout',
        ),
      ),
      '/social/google/callback?authorizationCode=fragment-code&callbackState=fragment-state&redirect=%2Fcheckout',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/social/apple/callback#/social/apple/callback?code=hash-route-code&state=hash-route-state',
        ),
      ),
      '/social/apple/callback?code=hash-route-code&state=hash-route-state',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/#/social/google/callback?code=hash-only-code&state=hash-only-state',
        ),
      ),
      '/social/google/callback?code=hash-only-code&state=hash-only-state',
    );
  });

  test('customer deep link normalizes checkout payment returns', () {
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://shop.example.com/checkout/pending?order_id=ord_1',
        ),
      ),
      '/checkout/pending?order_id=ord_1',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('newpaotang://checkout/pending?order_id=ord_1'),
      ),
      '/checkout/pending?order_id=ord_1',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('partnerlottery:///checkout/pending?order_id=ord_1'),
      ),
      '/checkout/pending?order_id=ord_1',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'https://payment.example.com/checkout/pending?order_id=ord_1',
        ),
        allowedHosts: const ['https://payment.example.com/callback'],
      ),
      '/checkout/pending?order_id=ord_1',
    );
  });

  test('customer deep link normalizes custom scheme callbacks', () {
    expect(
      customerDeepLinkPath(
        Uri.parse('newpaotang://line/callback?code=a&state=b'),
      ),
      '/line/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('newpaotang://social/apple/callback?code=a&state=b'),
      ),
      '/social/apple/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('newpaotang://social/line/callback?code=a&state=b'),
      ),
      '/social/line/callback?code=a&state=b',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'newpaotang://social/google/callback#code=fragment-code&state=fragment-state',
        ),
      ),
      '/social/google/callback?code=fragment-code&state=fragment-state',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse(
          'newpaotang://callback#/social/apple/callback?code=hash-code&state=hash-state',
        ),
      ),
      '/social/apple/callback?code=hash-code&state=hash-state',
    );
    expect(
      customerDeepLinkPath(Uri.parse('newpaotang://reset-password?token=abc')),
      '/reset-password?token=abc',
    );
    expect(
      customerDeepLinkPath(
        Uri.parse('newpaotang://reset-password?token=abc'),
        allowedHosts: const ['shop.example.com'],
      ),
      '/reset-password?token=abc',
    );
  });

  test('customer deep link allowed hosts derive from runtime config', () {
    expect(
      customerDeepLinkAllowedHosts(
        tenantHost: 'https://shop.example.com/app',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      {'shop.example.com'},
    );
    expect(
      customerDeepLinkAllowedHosts(
        tenantHost: '',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      {'api.example.com'},
    );
    expect(
      customerDeepLinkAllowedHosts(tenantHost: '', apiBaseUrl: '/api/v1'),
      isEmpty,
    );
    expect(
      customerDeepLinkAllowedHosts(
        tenantHost: 'configured.example.com',
        runtimeTenantHost: 'runtime.example.com',
        runtimeCanonicalUrl: 'https://canonical.example.com/customer',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      {
        'configured.example.com',
        'runtime.example.com',
        'canonical.example.com',
      },
    );
    expect(
      customerDeepLinkAllowedHosts(
        tenantHost: '',
        runtimeCanonicalUrl: 'https://shop.example.com',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      {'shop.example.com'},
    );
  });

  test('customer deep link rejects unknown customer routes', () {
    expect(
      customerDeepLinkPath(Uri.parse('https://shop.example.com/admin')),
      isNull,
    );
    expect(
      customerDeepLinkPath(Uri.parse('newpaotang://unknown/path')),
      isNull,
    );
  });
}
