import 'package:customer_flutter/core/utils/api_payload.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_deep_link.dart';
import 'package:customer_flutter/core/utils/api_errors.dart';
import 'package:customer_flutter/core/utils/asset_url.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
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

    expect(suspended.operationalRedirectPath, contains('/account-suspended'));
    expect(suspended.operationalRedirectPath, contains('reason='));
    expect(suspended.operationalRedirectPath, contains('suspended_until='));
    expect(permanent.operationalRedirectPath, contains('permanent=1'));
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

  test('social provider aliases normalize before routing to auth APIs', () {
    expect(normalizeSocialAuthProvider('line_login'), 'line');
    expect(normalizeSocialAuthProvider('line_oa'), 'line');
    expect(normalizeSocialAuthProvider('gmail'), 'google');
    expect(normalizeSocialAuthProvider('google_oauth2'), 'google');
    expect(normalizeSocialAuthProvider('apple_id'), 'apple');
    expect(normalizeSocialAuthProvider('sign_in_with_apple'), 'apple');

    final callback = SocialCallbackResult.fromJson({
      'provider': 'apple_id',
      'social_link_required': true,
      'social_link_token': 'apple-link-token',
    });

    expect(callback.provider, 'apple');
    expect(callback.linkToken, 'apple-link-token');
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
        'message': 'ปิดปรับปรุง',
        'expected_end_at': '2026-06-25T12:00:00+07:00',
        'retry_after_seconds': '120',
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
    expect(bootstrap.maintenance.retryAfterSeconds, 120);
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
          {'provider': 'line_login', 'enabled': true},
          {'provider': 'gmail', 'enabled': true, 'label': ''},
          {'provider': 'apple_id', 'enabled': true},
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
    expect(activity.resultSummary?.customerWon, isTrue);
    expect(activity.resultSummary?.customerAwardAmount, 300);
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
    expect(cart.items.single.reservationId, 'res_1');
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
    final unsafe = LotteryCheckoutOrder.fromJson({
      'id': 'ord_unsafe',
      'payment_method': 'external_payment',
      'redirect_url': 'javascript:alert(1)',
    });

    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_external'),
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
      'payment_methods': [
        {'key': 'qr', 'enabled': true},
        {'key': 'credit_card', 'enabled': false},
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
    expect(overview.waiting?.amount, 500);
    expect(overview.waiting?.status, TopupStatus.pendingPayment);
    expect(overview.waiting?.needsSlip, isTrue);
    expect(overview.histories.single.status, TopupStatus.approved);
    expect(overview.lastPage, 2);
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

  test('topup redirect URL maps to safe external payment URI', () {
    final item = TopupRequestItem.fromJson({
      'id': 'top_1',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'processing',
      'channel': 'credit_card',
      'payment': {'redirect_url': 'https://pay.example.test/session/123'},
    });
    final unsafe = TopupRequestItem.fromJson({
      'id': 'top_2',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'processing',
      'channel': 'credit_card',
      'payment': {'redirect_url': 'javascript:alert(1)'},
    });

    expect(item.redirectUri, Uri.parse('https://pay.example.test/session/123'));
    expect(unsafe.redirectUri, isNull);
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
      'bank_name': 'ธนาคารกรุงไทย',
      'bank_account_number': '006-123-4567',
      'wallet_name': 'Primary wallet',
    });

    final th = CustomerLocalizations(fallbackCustomerLocale);

    expect(claim.isPaid, isTrue);
    expect(claim.payoutLedgerId, 'ledger_1');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006-123-4567');
    expect(rewardClaimStatusLabel(th, claim), 'โอนเงินสำเร็จ');
    expect(rewardClaimPayoutSummary(th, claim), 'รับผ่านบัญชีกรุงไทย');
    expect(rewardClaimPayoutChannelText(th, claim), 'ธนาคารกรุงไทย\nx xxx4567');
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
    expect(claim.payoutLedgerId, 'ledger_activity_1');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(claim.bankAccountNumber, '123-456-7890');
    expect(status, 'โอนเงินสำเร็จ');
    expect(summary, 'รับผ่านบัญชีกสิกรไทย');
    expect(channel, 'ธนาคารกสิกรไทย\nx xxx7890');
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
    expect(profile.bankAccount.isComplete, isTrue);
    expect(profile.bankAccount.maskedNumber, '********6789');
    expect(profile.autoReward.enabled, isTrue);
    expect(profile.autoReward.isBankTransfer, isTrue);
    expect(maskWalletId(profile.customerNo), '006 XXXXXXXX 1234');
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
    final unsafe = PurchaseHistoryOrder.fromJson({
      'id': 'ord_unsafe',
      'payment_method': 'external_payment',
      'redirect_url': 'javascript:alert(1)',
    });

    expect(
      order.redirectUri,
      Uri.parse('https://pay.example.test/session/ord_pending'),
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
      customerDeepLinkPath(Uri.parse('newpaotang://reset-password?token=abc')),
      '/reset-password?token=abc',
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
