import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_locale_controller.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/payment/checkout_payment_config.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_repository.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:dio/dio.dart';

void main() {
  test('app config uses safe defaults', () {
    const config = AppConfig(apiBaseUrl: '/api/v1', defaultLocale: 'th-TH');

    expect(config.apiBaseUrl, '/api/v1');
    expect(config.defaultLocale, 'th-TH');
    expect(config.runtimeDisplayName, 'Customer');
    expect(config.defaultLocaleTag, 'th-TH');
    expect(config.normalizedTenantHost, '');
  });

  test('app config normalizes native tenant host hints', () {
    const config = AppConfig(
      apiBaseUrl: 'https://api.newpaotang.example.com/api/v1',
      defaultLocale: 'th-TH',
      tenantHost: 'https://partner.example.com/app',
    );

    expect(config.normalizedTenantHost, 'partner.example.com');
  });

  test('mobile bootstrap falls back to configured app display name', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {'site': <String, dynamic>{}},
      defaultSiteName: 'Partner Lottery',
    );

    expect(bootstrap.siteName, 'Partner Lottery');
  });

  test('mobile bootstrap maps waiting result live configuration', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'site': <String, dynamic>{},
        'live': {
          'waiting_result_youtube_url': 'https://youtu.be/demo',
          'waiting_result_youtube_embed_url':
              'https://www.youtube.com/embed/demo',
          'source': 'tenant_override',
        },
      },
    );

    expect(bootstrap.live.configured, isTrue);
    expect(
      bootstrap.live.launchUri?.toString(),
      'https://www.youtube.com/embed/demo',
    );
    expect(bootstrap.live.source, 'tenant_override');
  });

  test('mobile bootstrap accepts mobile live camelCase config aliases', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'liveConfig': {
          'waitingResultYoutubeUrl': 'https://youtu.be/fallback',
          'source': 'top_level',
        },
        'mobileConfig': {
          'liveConfig': {
            'waitingResultYoutubeEmbedUrl':
                'https://www.youtube.com/embed/mobile',
            'provider': 'mobile_bo',
          },
        },
      },
    );

    expect(
      bootstrap.live.waitingResultYoutubeUrl,
      'https://youtu.be/fallback',
    );
    expect(
      bootstrap.live.waitingResultYoutubeEmbedUrl,
      'https://www.youtube.com/embed/mobile',
    );
    expect(
      bootstrap.live.launchUri?.toString(),
      'https://www.youtube.com/embed/mobile',
    );
    expect(bootstrap.live.source, 'mobile_bo');
  });

  test(
      'mobile bootstrap merges BO wrapper aliases for realtime payment and security',
      () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'realtimeConfig': {
          'enabled': 'on',
          'websocketUrl': 'wss://root.example.test/app',
          'pusherKey': 'root-key',
          'channelAuthEndpoint': '/root/realtime/auth',
          'clientName': 'root-client',
        },
        'paymentConfig': {
          'checkoutPaymentMethods': ['wallet'],
          'defaultMethod': 'wallet',
        },
        'securityConfig': {
          'biometricConfig': {
            'enabled': 'on',
            'assertionTokenTtlSeconds': 240,
            'authenticationPromptCopy': {
              'localizedReason': 'Runtime biometric prompt',
              'deviceRegistrationReason': 'Runtime setup prompt',
              'localizedReasons': {
                'rewardClaim': 'Runtime reward claim prompt',
              },
            },
            'rewardBankUpdateReason': 'Runtime profile update prompt',
            'platformRequirements': {
              'ios': ['face_id'],
            },
          },
          'screenSecurity': {
            'secureRoutes': ['/security-secure'],
            'privacyOverlayTitle': 'Tenant Privacy Mode',
            'privacyOverlayDescription': 'Tenant sensitive content is hidden.',
          },
        },
        'mobileConfig': {
          'broadcastingConfig': {
            'wsUrl': 'wss://mobile.example.test/app',
            'appKey': 'mobile-key',
          },
          'checkoutPaymentConfig': {
            'enabledMethods': [
              {'paymentMethod': 'external-payment', 'status': 'available'},
              {'key': 'bank_transfer', 'enabled': true},
            ],
            'defaultCheckoutMethod': 'external',
          },
          'securityConfig': {
            'biometricsConfig': {
              'supportedPlatforms': {
                'android': {
                  'available': 'on',
                  'capabilities': ['biometric_prompt'],
                },
              },
            },
          },
        },
      },
    );

    expect(bootstrap.realtime.enabled, isTrue);
    expect(bootstrap.realtime.configured, isTrue);
    expect(bootstrap.realtime.url, 'wss://mobile.example.test/app');
    expect(bootstrap.realtime.key, 'mobile-key');
    expect(bootstrap.realtime.authEndpoint, '/root/realtime/auth');
    expect(bootstrap.realtime.client, 'root-client');
    expect(bootstrap.payment.checkoutPaymentMethod, 'external_payment');
    expect(bootstrap.payment.checkoutPaymentMethods, [
      checkoutPaymentMethodWallet,
      checkoutPaymentMethodExternalPayment,
    ]);
    expect(bootstrap.biometric.enabled, isTrue);
    expect(bootstrap.biometric.assertionTokenTtlSeconds, 240);
    expect(
      bootstrap.biometric.promptReasonForPurpose(
        'pin_unlock',
        fallback: 'Fallback prompt',
      ),
      'Runtime biometric prompt',
    );
    expect(
      bootstrap.biometric.promptReasonForPurpose(
        'biometric_setup',
        fallback: 'Fallback setup',
        setup: true,
      ),
      'Runtime setup prompt',
    );
    expect(
      bootstrap.biometric.promptReasonForPurpose(
        'reward_claim',
        fallback: 'Fallback reward',
      ),
      'Runtime reward claim prompt',
    );
    expect(
      bootstrap.biometric.promptReasonForPurpose(
        'profile_update',
        fallback: 'Fallback profile',
      ),
      'Runtime profile update prompt',
    );
    expect(bootstrap.biometric.platforms['ios'], ['face_id']);
    expect(bootstrap.biometric.platforms['android'], ['biometric_prompt']);
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/security-secure'),
      isTrue,
    );
    expect(bootstrap.screenSecurity.privacyOverlayTitle, 'Tenant Privacy Mode');
    expect(
      bootstrap.screenSecurity.privacyOverlayDescription,
      'Tenant sensitive content is hidden.',
    );
  });

  test('mobile bootstrap repository accepts standard data payload', () async {
    final repository = MobileBootstrapRepository(
      _BootstrapApiClient({
        'data': {
          'site': {'display_name': 'Data Shop'},
        },
      }),
    );

    final payload = await repository.load();

    expect(payload['site'], {'display_name': 'Data Shop'});
  });

  test('mobile bootstrap repository accepts legacy result payload', () async {
    final repository = MobileBootstrapRepository(
      _BootstrapApiClient({
        'result': {
          'site': {'display_name': 'Result Shop'},
        },
      }),
    );

    final payload = await repository.load();

    expect(payload['site'], {'display_name': 'Result Shop'});
  });

  test('mobile bootstrap repository accepts resource payload', () async {
    final repository = MobileBootstrapRepository(
      _BootstrapApiClient({
        'resource': {
          'site': {'display_name': 'Resource Shop'},
        },
      }),
    );

    final payload = await repository.load();

    expect(payload['site'], {'display_name': 'Resource Shop'});
  });

  test('mobile bootstrap accepts social provider production aliases', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'mobileConfig': {
          'authProviders': [
            {
              'key': 'line_oauth',
              'displayLabel': 'LINE',
              'isEnabled': true,
              'brandColor': '#00B900',
              'buttonBackgroundColor': {'hex': '#00C300'},
              'buttonForegroundColor': {'value': '#FFFFFF'},
            },
            {
              'provider': 'discord',
              'enabled': true,
            },
            {
              'provider': 'gmail',
              'enabled': false,
            },
          ],
        },
        'socialProviders': {
          'providers': [
            {
              'provider': 'line',
              'label': 'Duplicate LINE',
              'enabled': true,
            },
          ],
          'google_oauth2': {
            'displayName': 'Google Login',
            'status': 'available',
            'colors': {'primary': '#4285F4'},
          },
          'apple_login': {
            'status': 'ready',
            'brand': {'color': '#111111'},
          },
        },
      },
    );

    expect(
      bootstrap.authProviders.map((provider) => provider.provider),
      ['line', 'google', 'apple'],
    );
    expect(
      bootstrap.authProviders.map((provider) => provider.label),
      ['LINE', 'Google Login', 'Apple ID'],
    );
    expect(bootstrap.authProviders[0].brandColor, const Color(0xFF00B900));
    expect(
      bootstrap.authProviders[0].buttonBackgroundColor,
      const Color(0xFF00C300),
    );
    expect(
      bootstrap.authProviders[0].buttonForegroundColor,
      const Color(0xFFFFFFFF),
    );
    expect(bootstrap.authProviders[1].brandColor, const Color(0xFF4285F4));
    expect(bootstrap.authProviders[2].brandColor, const Color(0xFF111111));
  });

  test('mobile bootstrap accepts biometric platform allowlist aliases', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'mobileConfig': {
          'biometricConfig': {
            'enabled': true,
            'supportedPlatforms': [
              {
                'platform': 'ios',
                'capabilities': ['face_id'],
              },
              {
                'platform': 'android',
                'enabled': false,
                'capabilities': ['biometric_prompt'],
              },
              'macos',
            ],
          },
        },
      },
    );

    expect(bootstrap.biometric.supportsPlatform('ios'), isTrue);
    expect(bootstrap.biometric.platforms['ios'], ['face_id']);
    expect(bootstrap.biometric.supportsPlatform('android'), isFalse);
    expect(bootstrap.biometric.supportsPlatform('macos'), isTrue);

    final keyed = MobileBootstrap.fromJson(
      const {
        'mobileConfig': {
          'biometricConfig': {
            'enabled': 'on',
            'platforms': {
              'ios': true,
              'android': false,
              'macos': {
                'available': 'on',
                'capabilities': ['touch_id'],
              },
              'windows': 'supported',
            },
          },
        },
      },
    );

    expect(keyed.biometric.enabled, isTrue);
    expect(keyed.biometric.supportsPlatform('ios'), isTrue);
    expect(keyed.biometric.supportsPlatform('android'), isFalse);
    expect(keyed.biometric.supportsPlatform('macos'), isTrue);
    expect(keyed.biometric.platforms['macos'], ['touch_id']);
    expect(keyed.biometric.supportsPlatform('windows'), isTrue);
  });

  test('mobile bootstrap accepts screen security route policy aliases', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'mobileConfig': {
          'screenSecurity': {
            'secureRoutes': [
              'https://partner.example.com/my-wallet?tab=summary',
              'customer://screen-security?route=%2Fcheckout%2Fpending%3Forder_id%3Dord_1',
            ],
            'android': {
              'protectedRoutes': '/reward-claims,/activity-claims/:claimId',
            },
            'ios': {
              'sensitiveRoutes': [
                {'path': '/tickets/:ticketId', 'status': 'available'},
                {
                  'currentUrl':
                      'https://partner.example.com/tickets/ticket_42?tab=image',
                  'status': 'available',
                },
                {'route': '/disabled-native', 'enabled': 'off'},
              ],
            },
            'web': {
              'routePatterns': [
                'https://partner.example.com/partner-secure/*?view=hidden',
                {
                  '#/profile/account-deletion?intent=delete': 'on',
                  '/disabled-web': false,
                },
              ],
            },
          },
        },
      },
    );

    expect(bootstrap.screenSecurity.sensitiveRoutes, [
      '/my-wallet',
      '/checkout/pending',
      '/reward-claims',
      '/activity-claims/:claimId',
      '/tickets/:ticketId',
      '/tickets/ticket_42',
      '/partner-secure/*',
      '/profile/account-deletion',
    ]);
    expect(bootstrap.screenSecurity.isSensitiveRoute('/my-wallet'), isTrue);
    expect(
      bootstrap.screenSecurity.isSensitiveRoute(
        'https://partner.example.com/my-wallet/ledger?tab=latest',
      ),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute(
        'customer://screen-security?route=%2Fcheckout%2Fpending%3Forder_id%3Dord_2',
      ),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/reward-claims/claim_1'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/activity-claims/claim_2'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/partner-secure/report'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/tickets/ticket_1'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/profile/account-deletion'),
      isTrue,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/disabled-native'),
      isFalse,
    );
    expect(
      bootstrap.screenSecurity.isSensitiveRoute('/disabled-web'),
      isFalse,
    );
  });

  test('mobile bootstrap normalizes feature and plugin flag aliases', () {
    final bootstrap = MobileBootstrap.fromJson(
      const {
        'siteConfig': {
          'featureFlags': {
            'nativeBiometricUnlock': true,
          },
        },
        'features': [
          {'key': 'screen-security-native', 'status': 'disabled'},
          {'pluginKey': 'customer.realtime.monitor', 'enabled': 'on'},
        ],
        'mobileConfig': {
          'pluginSettings': {
            'native-biometric-unlock': {'allowed': false},
            'screenSecurityNative': {'supported': 'yes'},
          },
          'features': {
            'claims': {
              'rewardClaims': {'status': 'available'},
            },
          },
          'enabledPlugins': ['wallet.topup'],
        },
      },
    );

    expect(
      bootstrap.featureFlags.enabled(
        'native_biometric_unlock',
        fallback: true,
      ),
      isFalse,
    );
    expect(bootstrap.featureFlags.enabled('screen_security_native'), isTrue);
    expect(bootstrap.featureFlags.enabled('customer_realtime_monitor'), isTrue);
    expect(bootstrap.featureFlags.enabled('reward_claims'), isTrue);
    expect(bootstrap.featureFlags.enabled('wallet_topup'), isTrue);
    expect(
      bootstrap.featureFlags.enabled('missing_flag', fallback: true),
      isTrue,
    );
  });

  test('mobile bootstrap accepts tenant id and site name aliases', () {
    final nestedTenant = MobileBootstrap.fromJson(
      const {
        'siteConfig': {
          'siteName': 'Nested Tenant Shop',
          'tenant': {'id': 'tenant_nested_1'},
        },
      },
    );
    final topLevelTenant = MobileBootstrap.fromJson(
      const {
        'site': {'name': 'Top Level Tenant Shop'},
        'tenantId': 'tenant_top_1',
      },
    );

    expect(nestedTenant.siteName, 'Nested Tenant Shop');
    expect(nestedTenant.tenantId, 'tenant_nested_1');
    expect(topLevelTenant.siteName, 'Top Level Tenant Shop');
    expect(topLevelTenant.tenantId, 'tenant_top_1');
  });

  test('customer locale parser supports tenant locale tags', () {
    expect(localeTag(parseCustomerLocale('th')), 'th-TH');
    expect(localeTag(parseCustomerLocale('th_TH')), 'th-TH');
    expect(localeTag(parseCustomerLocale('en')), 'en-US');
    expect(localeTag(parseCustomerLocale('en-US')), 'en-US');
  });

  test('customer locale parser falls back for unsupported tags', () {
    final fallback = parseCustomerLocale('en-US');

    expect(localeTag(parseCustomerLocale('ja-JP')), 'th-TH');
    expect(
      localeTag(parseCustomerLocale('ja-JP', fallback: fallback)),
      'en-US',
    );
  });

  test('customer localizations expose Thai and English app shell labels', () {
    const thai = CustomerLocalizations(fallbackCustomerLocale);
    const english = CustomerLocalizations(Locale('en', 'US'));

    expect(thai.bottomNavHome, 'หน้าหลัก');
    expect(english.bottomNavHome, 'Home');
    expect(thai.commonLanguage, 'ภาษา');
    expect(english.commonLanguage, 'Language');
    expect(thai.commonThai, 'ไทย');
    expect(english.commonEnglish, 'English');
    expect(thai.appAlertDefaultTitle, 'แจ้งเตือน');
    expect(english.appAlertDefaultTitle, 'Notice');
    expect(thai.appAlertDefaultButton, 'รับทราบ');
    expect(english.appAlertDefaultButton, 'OK');
    expect(thai.appSplashPreparing, 'กำลังเตรียมข้อมูลระบบ');
    expect(english.appSplashPreparing, 'Preparing system data');
    expect(thai.saleClosureAlertMessage, contains('หน้ารอออกผล'));
    expect(english.saleClosureAlertMessage, contains('waiting-for-results'));
    expect(thai.pinBiometricReason, 'ยืนยันตัวตนเพื่อปลดล็อกและดำเนินการต่อ');
    expect(english.pinBiometricReason, 'Authenticate to unlock and continue');
    expect(thai.loginRememberMe, 'จดจำการเข้าสู่ระบบ');
    expect(english.loginRememberMe, 'Remember me');
    expect(english.socialLoginLabel('Google'), 'Continue with Google');
    expect(thai.registerTitle, 'สมัครใช้งาน');
    expect(english.registerTitle, 'Create account');
    expect(thai.authOtpResendIn(12), 'ส่งใหม่ได้ใน 12 วินาที');
    expect(english.authOtpResendIn(12), 'Resend in 12s');
    expect(thai.forgotPasswordTitle, 'ลืมรหัสผ่าน');
    expect(english.forgotPasswordTitle, 'Forgot password');
    expect(thai.forgotPasswordLineTitle, 'รีเซ็ตด้วย LINE');
    expect(english.forgotPasswordLineTitle, 'Reset with LINE');
    expect(
      thai.forgotPasswordOtpProviderUnavailable,
      contains('ยังไม่ได้เปิดบริการ OTP'),
    );
    expect(
      english.forgotPasswordOtpProviderUnavailable,
      contains('has not enabled OTP password reset'),
    );
    expect(thai.resetPasswordTitle, 'ตั้งรหัสผ่านใหม่');
    expect(english.resetPasswordTitle, 'Set new password');
    expect(
      thai.pinResetOtpProviderUnavailable,
      contains('ยังไม่ได้เปิดบริการ OTP'),
    );
    expect(
      english.pinResetOtpProviderUnavailable,
      contains('has not enabled OTP PIN reset'),
    );
    expect(thai.socialLinkTitle('LINE'), 'ผูกบัญชีด้วย LINE');
    expect(english.socialLinkTitle('LINE'), 'Link account with LINE');
    expect(thai.contentPrivacyTitle, 'นโยบายความเป็นส่วนตัว');
    expect(english.contentPrivacyTitle, 'Privacy policy');
    expect(thai.profilePrivacyPolicy, 'นโยบายความเป็นส่วนตัว');
    expect(english.profileAccountDeletion, 'Delete account');
    expect(thai.homeBuyLotteryTitle, 'ซื้อสลากดิจิทัล');
    expect(english.homeBuyLotteryTitle, 'Buy digital lottery');
    expect(thai.resultTitle, 'ผลรางวัลสลากฯ');
    expect(english.resultTitle, 'Lottery results');
    expect(thai.resultRewardTitle('reward_two_digit'), 'เลขท้าย 2 ตัว');
    expect(english.resultRewardTitle('reward_two_digit'), 'Last 2 digits');
    expect(thai.waitingResultPending, 'รอประกาศผลรางวัล');
    expect(english.waitingResultPending, 'Waiting for result announcement');
    expect(
      thai.maintenanceTitle('ร้านเดโม'),
      'ร้านเดโม อยู่ระหว่างปิดปรับปรุง',
    );
    expect(
      english.maintenanceTitle('Demo Shop'),
      'Demo Shop is under maintenance',
    );
    expect(thai.accountSuspendedPermanent, 'ระงับถาวร');
    expect(english.accountSuspendedPermanent, 'Permanently suspended');
    expect(thai.countdownDay, 'วัน');
    expect(english.countdownDay, 'Days');
    expect(thai.successTitle, 'ทำรายการสำเร็จ');
    expect(english.successTitle, 'Transaction successful');
    expect(thai.successTransactionAtLabel, 'วันที่ทำรายการ');
    expect(english.successTransactionAtLabel, 'Transaction date');
    expect(thai.newsTitle, 'ข่าวสาร');
    expect(english.newsTitle, 'News');
    expect(thai.newsEmptyTitle, 'ยังไม่มีข่าวสาร');
    expect(english.newsEmptyTitle, 'No news yet');
    expect(thai.newsModalClose, 'ปิดข่าวประชาสัมพันธ์');
    expect(english.newsModalClose, 'Close announcement');
    expect(thai.contentTermsTitle, 'ข้อตกลงและเงื่อนไข');
    expect(english.contentTermsTitle, 'Terms and conditions');
    expect(
      thai.contentTermsDefaultContent('ร้านเดโม').contains('ร้านเดโม'),
      isTrue,
    );
    expect(
      english.contentTermsDefaultContent('Demo Shop').contains('Demo Shop'),
      isTrue,
    );
    expect(thai.contentRewardHeaderPrizeType, 'ประเภทรางวัล');
    expect(english.contentRewardHeaderPrizeType, 'Prize type');
    expect(thai.contentRewardRowAmount('first'), '6,000,000 บาท');
    expect(english.contentRewardRowAmount('first'), '6,000,000 THB');
    expect(thai.commonBahtSuffix, 'บาท');
    expect(english.commonBahtSuffix, 'THB');
    expect(thai.formatBaht(1234), '1,234.00 บาท');
    expect(english.formatBaht(1234), '1,234.00 THB');
    expect(thai.contentKnowledgeTitle, 'ข้อควรรู้การซื้อ-ขายสลากฯ');
    expect(
      english.contentKnowledgeTitle,
      'Lottery buying and selling knowledge',
    );
    expect(thai.commonLoadingData, 'กำลังโหลดข้อมูล...');
    expect(english.commonLoadingData, 'Loading data...');
    expect(thai.affiliateTitle, 'ตัวแทนจำหน่าย');
    expect(english.affiliateTitle, 'Affiliate');
    expect(thai.affiliatePinTitle, 'ใส่รหัส PIN 6 หลัก');
    expect(english.affiliatePinTitle, 'Enter 6-digit PIN');
    expect(thai.affiliateStatTitle('available'), 'ยอดถอนได้');
    expect(english.affiliateStatTitle('available'), 'Available');
    expect(thai.affiliateTabLabel('withdraw'), 'ถอน');
    expect(english.affiliateTabLabel('withdraw'), 'Withdraw');
    expect(
      thai.affiliateWithdrawMinimum('300.00 บาท'),
      'ถอนขั้นต่ำ 300.00 บาท',
    );
    expect(
      english.affiliateWithdrawMinimum('300.00 THB'),
      'Minimum withdrawal 300.00 THB',
    );
    expect(thai.affiliateStatusLabel('approved'), 'อนุมัติแล้ว');
    expect(english.affiliateStatusLabel('approved'), 'Approved');
    expect(thai.activityTypeLabel('lucky_board'), 'แผงเลขนำโชค');
    expect(english.activityTypeLabel('lucky_board'), 'Lucky board');
    expect(thai.activityPredictionLabel('last2'), 'เลขท้าย 2 ตัว');
    expect(english.activityPredictionLabel('last2'), 'Last 2 digits');
    expect(thai.activityMetaRights(2), 'มีสิทธิ์ 2 สิทธิ์');
    expect(english.activityMetaRights(2), '2 right(s) available');
    expect(thai.activityDetailTitle, 'รายละเอียดกิจกรรม');
    expect(english.activityDetailTitle, 'Activity details');
    expect(thai.activityAwardReady, 'พร้อมรับเงินรางวัล');
    expect(english.activityAwardReady, 'Ready to claim');
    expect(thai.activityClaimBiometricButton, 'ใช้ Face ID / Biometric');
    expect(english.activityClaimBiometricButton, 'Use Face ID / Biometric');
    expect(thai.profileLogout, 'ออกจากระบบ');
    expect(english.profileLogout, 'Sign out');
    expect(thai.profileLanguageTitle, 'ภาษาในการใช้งาน');
    expect(english.profileLanguageTitle, 'Display language');
    expect(thai.profileLanguageSubtitle, contains('เลือกภาษา'));
    expect(english.profileLanguageSubtitle, contains('Choose the language'));
    expect(thai.profileLanguageSaveFailed, contains('บันทึก'));
    expect(english.profileLanguageSaveFailed, contains('could not be saved'));
    expect(thai.profileSectionHistory, 'ประวัติ');
    expect(english.profileSectionHistory, 'History');
    expect(thai.profileSectionRewardSettings, 'ตั้งค่ารับเงินรางวัล');
    expect(english.profileSectionRewardSettings, 'Reward payout settings');
    expect(thai.profileSectionAbout, 'เกี่ยวกับแอปฯ');
    expect(english.profileSectionAbout, 'About this app');
    expect(thai.profileBadgeNew, 'ใหม่');
    expect(english.profileBadgeNew, 'New');
    expect(thai.profileBadgeRecommended, 'แนะนำ');
    expect(english.profileBadgeRecommended, 'Recommended');
    expect(thai.profileRewardBank, 'บัญชีรับเงินรางวัล');
    expect(english.profileRewardBank, 'Reward payout account');
    expect(thai.profileRewardBankSaveButton, 'บันทึกบัญชีรับเงิน');
    expect(english.profileRewardBankSaveButton, 'Save payout account');
    expect(thai.profileAutoReward, 'ขึ้นเงินรางวัลอัตโนมัติ');
    expect(english.profileAutoReward, 'Automatic reward claim');
    expect(
      thai.profileAutoRewardSelectTitle,
      'เลือกช่องทางรับเงินรางวัลหลัก',
    );
    expect(
      english.profileAutoRewardSelectTitle,
      'Choose primary reward payout channel',
    );
    expect(
      thai.profileAutoRewardBenefitFast('ร้านตัวอย่าง'),
      'ได้เงินเร็ว หลัง ร้านตัวอย่าง ตรวจสอบรายการ',
    );
    expect(
      english.profileAutoRewardSelectSubtitle('Demo Store'),
      'The system will claim lottery rewards and submit the payout request to Demo Store using your selected primary channel.',
    );
    expect(
      thai.activityClaimWalletSubtitle('ร้านตัวอย่าง'),
      'เงินเข้ากระเป๋าในระบบหลัง ร้านตัวอย่าง อนุมัติ',
    );
    expect(thai.profileAutoRewardPinTitle, 'ใส่รหัส PIN 6 หลัก');
    expect(english.profileAutoRewardPinTitle, 'Enter 6-digit PIN');
    expect(thai.profileLineConnect, 'เชื่อมต่อ LINE');
    expect(english.profileLineConnect, 'Connect LINE');
    expect(thai.profileLineEventOrder, 'ซื้อสลากและยืนยันคำสั่งซื้อ');
    expect(
      english.profileLineEventOrder,
      'Lottery purchases and order confirmations',
    );
    expect(thai.profileBiometricEnableButton, 'เปิดใช้ biometric');
    expect(english.profileBiometricEnableButton, 'Enable biometric');
    expect(
      thai.profileBiometricSetupReason,
      'ยืนยัน biometric เพื่อเปิดใช้แทน PIN บนอุปกรณ์นี้',
    );
    expect(
      english.profileBiometricSetupReason,
      'Authenticate to enable biometric unlock on this device',
    );
    expect(thai.profileBiometricStatusActive, 'เปิดใช้งาน');
    expect(english.profileBiometricStatusActive, 'Active');
    expect(thai.walletBalanceAfter('100.00 บาท'), 'คงเหลือ 100.00 บาท');
    expect(english.walletBalanceAfter('100.00 THB'), 'Balance 100.00 THB');
    expect(thai.topupTitle, 'เติมเงินเข้า G-Wallet');
    expect(english.topupTitle, 'Top up G-Wallet');
    expect(thai.topupOpenPayment, 'เปิดหน้าชำระเงิน');
    expect(english.topupOpenPayment, 'Open payment page');
    expect(thai.topupStatusPendingReview, 'รอตรวจสอบ');
    expect(english.topupStatusPendingReview, 'Pending review');
    expect(thai.rewardClaimsTitle, 'ประวัติขึ้นเงินรางวัล');
    expect(english.rewardClaimsTitle, 'Reward claim history');
    expect(thai.ticketsTitle, 'สลากฯ ของฉัน');
    expect(english.ticketsTitle, 'My Tickets');
    expect(thai.ticketsCount(2), '2 ใบ');
    expect(english.ticketsCount(2), '2 ticket(s)');
    expect(thai.ticketClaimStart, 'ขึ้นเงินรางวัล');
    expect(english.ticketClaimStart, 'Claim reward');
    expect(thai.ticketClaimLoading, 'กำลังโหลดข้อมูลรางวัล...');
    expect(english.ticketClaimLoading, 'Loading reward information...');
    expect(thai.ticketClaimPayoutMethodTitle, 'ช่องทางขึ้นเงินรางวัล');
    expect(english.ticketClaimPayoutMethodTitle, 'Reward payout channel');
    expect(thai.ticketImagePreparing, 'รูปสลากกำลังเตรียมพร้อม');
    expect(english.ticketImagePreparing, 'Ticket image is being prepared');
    expect(thai.lotteryBuyTitle, 'ซื้อสลากดิจิทัล');
    expect(english.lotteryBuyTitle, 'Buy digital lottery');
    expect(thai.lotteryAddedToCart, 'เพิ่มสลากลงตะกร้าแล้ว');
    expect(english.lotteryAddedToCart, 'Ticket added to cart.');
    expect(thai.cartHeaderCount(2), 'สลากฯ 2 ใบ');
    expect(english.cartHeaderCount(2), '2 lottery ticket(s)');
    expect(thai.cartSummary(2, '160.00 บาท'), '2 ใบ • 160.00 บาท');
    expect(english.cartSummary(2, '160.00 THB'), '2 ticket(s) • 160.00 THB');
    expect(thai.checkoutConfirm, 'ยืนยันชำระเงิน');
    expect(english.checkoutConfirm, 'Confirm payment');
    expect(thai.topupHistoryTitle, 'ประวัติเติมเงิน');
    expect(english.topupHistoryTitle, 'Topup history');
    expect(
      thai.topupHistoryReference('ABC', 'QR Code', 'วันนี้'),
      'รายการ #ABC\nQR Code • วันนี้',
    );
    expect(
      english.topupHistoryReference('ABC', 'QR Code', 'today'),
      'Request #ABC\nQR Code • today',
    );
    expect(thai.rewardClaimDetailTitle, 'รายละเอียดการขึ้นเงินรางวัล');
    expect(english.rewardClaimDetailTitle, 'Reward claim details');
    expect(thai.rewardClaimStatusPaid, 'โอนเงินสำเร็จ');
    expect(english.rewardClaimStatusPaid, 'Paid successfully');
    expect(thai.activityClaimsTitle, 'ประวัติขึ้นเงินรางวัลกิจกรรม');
    expect(english.activityClaimsTitle, 'Activity reward claim history');
    expect(
      thai.activityClaimsLoading,
      'กำลังโหลดประวัติขึ้นเงินกิจกรรม...',
    );
    expect(
      english.activityClaimsLoading,
      'Loading activity reward claim history...',
    );
    expect(thai.activityClaimRewardCashback, 'เงินคืนกิจกรรม');
    expect(english.activityClaimRewardCashback, 'Activity cashback');
    expect(thai.activityClaimStatusSubmitted, 'รอดำเนินการโอนเงิน');
    expect(english.activityClaimStatusSubmitted, 'Transfer pending');
    expect(thai.activitiesLoading, 'กำลังโหลดกิจกรรม');
    expect(english.activitiesLoading, 'Loading activities');
    expect(thai.activitiesHistoryLoading, 'กำลังโหลดกิจกรรมย้อนหลัง');
    expect(english.activitiesHistoryLoading, 'Loading past activities');
    expect(thai.purchaseHistoryTitle, 'ประวัติการซื้อสลากฯ');
    expect(english.purchaseHistoryTitle, 'Purchase history');
    expect(thai.purchaseHistoryTicketCount(3), '3 ใบ');
    expect(english.purchaseHistoryTicketCount(3), '3 ticket(s)');
    expect(thai.purchaseHistoryDetailTitle, 'รายละเอียดการซื้อสลากฯ');
    expect(english.purchaseHistoryDetailTitle, 'Purchase details');
    expect(thai.storesTitle, 'ร้านค้า');
    expect(english.storesTitle, 'Stores');
    expect(thai.storeCode('PCHOKE'), 'รหัสร้าน PCHOKE');
    expect(english.storeCode('PCHOKE'), 'Store code PCHOKE');
    expect(thai.storesTicketAvailable, 'พร้อมขาย');
    expect(english.storesTicketAvailable, 'Available');
  });

  test('mobile bootstrap resolves locale from site payload', () {
    final bootstrap = MobileBootstrap.fromJson({
      'site': {
        'display_name': 'Partner Demo',
        'locale': 'en-US',
      },
    });

    expect(bootstrap.siteName, 'Partner Demo');
    expect(localeTag(bootstrap.locale), 'en-US');
  });

  test('mobile bootstrap falls back to configured default locale', () {
    final bootstrap = MobileBootstrap.fromJson(
      {
        'site': {'display_name': 'Partner Demo'},
      },
      defaultLocale: 'en-US',
    );

    expect(localeTag(bootstrap.locale), 'en-US');
  });

  test('mobile bootstrap maps checkout payment config with safe fallback', () {
    final bootstrap = MobileBootstrap.fromJson({
      'mobile': {
        'payment': {
          'checkout_payment_methods': [
            checkoutPaymentMethodWallet,
            checkoutPaymentMethodExternalPayment,
          ],
          'checkout_payment_method': checkoutPaymentMethodExternalPayment,
        },
      },
    });

    expect(
      bootstrap.payment.checkoutPaymentMethods,
      [
        checkoutPaymentMethodWallet,
        checkoutPaymentMethodExternalPayment,
      ],
    );
    expect(
      bootstrap.payment.checkoutPaymentMethod,
      checkoutPaymentMethodExternalPayment,
    );

    final defaultOnly = MobileBootstrap.fromJson({
      'mobile': {
        'payment': {
          'checkout_payment_method': checkoutPaymentMethodExternalPayment,
        },
      },
    });

    expect(
      defaultOnly.payment.checkoutPaymentMethods,
      [
        checkoutPaymentMethodExternalPayment,
        checkoutPaymentMethodWallet,
      ],
    );
    expect(
      defaultOnly.payment.checkoutPaymentMethod,
      checkoutPaymentMethodExternalPayment,
    );

    final invalid = MobileBootstrap.fromJson({
      'payment': {
        'checkout_payment_methods': ['cash'],
        'checkout_payment_method': 'cash',
      },
    });

    expect(
      invalid.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodWallet],
    );
    expect(invalid.payment.checkoutPaymentMethod, checkoutPaymentMethodWallet);

    final objectRows = MobileBootstrap.fromJson({
      'mobileConfig': {
        'payment': {
          'checkoutPaymentMethods': [
            {
              'key': checkoutPaymentMethodExternalPayment,
              'enabled': true,
            },
            {
              'paymentMethod': checkoutPaymentMethodWallet,
              'status': 'disabled',
            },
            {
              'key': 'cash',
              'enabled': true,
            },
          ],
          'defaultCheckoutPaymentMethod': checkoutPaymentMethodExternalPayment,
        },
      },
    });

    expect(
      objectRows.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodExternalPayment],
    );
    expect(
      objectRows.payment.checkoutPaymentMethod,
      checkoutPaymentMethodExternalPayment,
    );
  });

  test('mobile bootstrap accepts public site payment method aliases', () {
    final publicSitePayment = MobileBootstrap.fromJson({
      'payment': {
        'methods': [
          {'key': 'qr', 'enabled': true},
          {'key': 'bank_transfer', 'enabled': true},
        ],
        'enabled_methods': [
          'external-payment',
          {'key': checkoutPaymentMethodWallet, 'enabled': false},
        ],
        'default_method': 'externalPayment',
      },
    });

    expect(
      publicSitePayment.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodExternalPayment],
    );
    expect(
      publicSitePayment.payment.checkoutPaymentMethod,
      checkoutPaymentMethodExternalPayment,
    );

    final keyedMethods = MobileBootstrap.fromJson({
      'mobileConfig': {
        'payment': {
          'checkoutMethods': {
            checkoutPaymentMethodWallet: true,
            'externalPayment': {'status': 'disabled'},
          },
        },
      },
    });

    expect(
      keyedMethods.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodWallet],
    );
  });

  test('mobile bootstrap respects checkout support visibility aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'payment': {
        'checkoutMethods': [
          {'paymentMethod': 'wallet', 'visible': false},
          {'paymentMethod': 'externalPayment', 'supported': 'yes'},
          {'paymentMethod': 'cash', 'available': 'on'},
        ],
        'defaultMethod': 'externalPayment',
      },
    });

    expect(
      bootstrap.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodExternalPayment],
    );
    expect(
      bootstrap.payment.checkoutPaymentMethod,
      checkoutPaymentMethodExternalPayment,
    );

    final keyed = MobileBootstrap.fromJson({
      'mobileConfig': {
        'paymentConfig': {
          'enabledMethods': {
            'wallet': {'allowed': false},
            'externalPayment': {'status': 'supported'},
            'external_provider': {'hidden': true},
          },
        },
      },
    });

    expect(
      keyed.payment.checkoutPaymentMethods,
      [checkoutPaymentMethodExternalPayment],
    );
  });

  test('mobile bootstrap accepts support phone contact aliases', () {
    final topLevel = MobileBootstrap.fromJson(
      const {
        'supportPhone': '021111111',
      },
    );
    final nestedContact = MobileBootstrap.fromJson(
      const {
        'mobileConfig': {
          'supportConfig': {
            'phoneNumber': '022222222',
            'emailAddress': 'support@example.test',
          },
        },
      },
    );

    expect(topLevel.supportPhone, '021111111');
    expect(nestedContact.supportPhone, '022222222');
    expect(nestedContact.supportEmail, 'support@example.test');
  });

  test('api client follows active runtime customer locale', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(apiClientProvider).currentLocaleTag, 'th-TH');

    container.read(customerLocaleProvider.notifier).state = const Locale(
      'en',
      'US',
    );

    expect(container.read(apiClientProvider).currentLocaleTag, 'en-US');
  });

  test('api client carries native tenant host runtime config', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://api.newpaotang.example.com/api/v1',
            defaultLocale: 'th-TH',
            tenantHost: 'https://partner.example.com',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(apiClientProvider).currentTenantHost,
      'partner.example.com',
    );
  });

  testWidgets('manual customer locale selection wins over bootstrap sync', (
    tester,
  ) async {
    final observed = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: '/api/v1', defaultLocale: 'th-TH'),
          ),
        ],
        child: _LocaleOverrideProbe(observed: observed),
      ),
    );
    await tester.pump();

    expect(observed, ['en-US', 'th-TH']);
  });

  test('mobile bootstrap maps partner brand and theme payload', () {
    final bootstrap = MobileBootstrap.fromJson({
      'site': {
        'display_name': 'Partner Demo',
        'locale': 'th-TH',
      },
      'mobile': {
        'lottery_product_label': 'L6',
        'ticket_image_watermark': 'GLO',
      },
      'brand': {
        'logo_url': 'https://partner.example/logo.webp',
        'favicon_url': 'https://partner.example/favicon.ico',
        'og_image_url': 'https://partner.example/og.webp',
      },
      'theme': {
        'primary_color': '#123456',
        'secondary_color': '#2255AA',
        'accent_color': '#FFAA00',
        'background_color': '#FAFBFC',
        'text_color': '#111827',
        'font_family': 'Prompt',
      },
    });

    expect(bootstrap.brand.logoUrl, 'https://partner.example/logo.webp');
    expect(bootstrap.lotteryProductLabel, 'L6');
    expect(bootstrap.ticketImageWatermark, 'GLO');
    expect(bootstrap.brand.faviconUrl, 'https://partner.example/favicon.ico');
    expect(bootstrap.brand.ogImageUrl, 'https://partner.example/og.webp');
    expect(bootstrap.theme.primaryColor, const Color(0xFF123456));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF2255AA));
    expect(bootstrap.theme.accentColor, const Color(0xFFFFAA00));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFFAFBFC));
    expect(bootstrap.theme.textColor, const Color(0xFF111827));
    expect(bootstrap.theme.fontFamily, 'Prompt');
  });

  test('mobile bootstrap maps camelCase partner brand and theme payload', () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'displayName': 'Partner Camel',
        'locale': 'en-US',
      },
      'mobileConfig': {
        'product_marker': 'L6',
        'themeConfig': {
          'colors': {
            'primary': '#224488',
            'secondaryColor': '#0EA5E9',
            'accent': '#F59E0B',
            'surface': '#F9FAFB',
            'onSurface': '#172033',
          },
          'fontFamily': 'Inter',
        },
      },
      'brandConfig': {
        'logoUrl': 'https://partner.example/logo-camel.webp',
        'faviconUrl': 'https://partner.example/favicon-camel.ico',
        'ogImageUrl': 'https://partner.example/og-camel.webp',
      },
    });

    expect(bootstrap.siteName, 'Partner Camel');
    expect(bootstrap.brand.logoUrl, 'https://partner.example/logo-camel.webp');
    expect(
      bootstrap.brand.faviconUrl,
      'https://partner.example/favicon-camel.ico',
    );
    expect(bootstrap.brand.ogImageUrl, 'https://partner.example/og-camel.webp');
    expect(bootstrap.lotteryProductLabel, 'L6');
    expect(bootstrap.theme.primaryColor, const Color(0xFF224488));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF0EA5E9));
    expect(bootstrap.theme.accentColor, const Color(0xFFF59E0B));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFF9FAFB));
    expect(bootstrap.theme.textColor, const Color(0xFF172033));
    expect(bootstrap.theme.fontFamily, 'Inter');
  });

  test('mobile bootstrap merges mobile brand and design token theme payload',
      () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'displayName': 'Partner Token Theme',
        'locale': 'en-US',
      },
      'brand': <String, dynamic>{},
      'theme': <String, dynamic>{},
      'mobileConfig': {
        'brandConfig': {
          'logoUrl': 'https://partner.example/mobile-logo.webp',
          'faviconUrl': 'https://partner.example/mobile-favicon.ico',
        },
        'themeConfig': {
          'brand': {
            'primary': '#102A43',
            'secondary': '#38BDF8',
          },
          'semantic': {
            'cta': '#F97316',
            'background': '#F8FAFC',
            'text': '#0F172A',
          },
          'typography': {'fontFamily': 'Kanit'},
        },
      },
    });

    expect(bootstrap.brand.logoUrl, 'https://partner.example/mobile-logo.webp');
    expect(
      bootstrap.brand.faviconUrl,
      'https://partner.example/mobile-favicon.ico',
    );
    expect(bootstrap.theme.primaryColor, const Color(0xFF102A43));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF38BDF8));
    expect(bootstrap.theme.accentColor, const Color(0xFFF97316));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFF8FAFC));
    expect(bootstrap.theme.textColor, const Color(0xFF0F172A));
    expect(bootstrap.theme.fontFamily, 'Kanit');
  });

  test('mobile bootstrap accepts nested design-token theme wrappers', () {
    final bootstrap = MobileBootstrap.fromJson({
      'siteConfig': {
        'displayName': 'Partner Design Tokens',
        'locale': 'th-TH',
      },
      'mobileConfig': {
        'themeConfig': {
          'designTokens': {
            'colors': {
              'primary': '#0F4C81',
              'secondary': '#14B8A6',
            },
            'semantic': {
              'cta': '#F59E0B',
              'surface': '#F7FAFC',
              'onSurface': '#111827',
            },
            'type': {'family': 'Sarabun'},
          },
        },
      },
    });

    expect(bootstrap.theme.primaryColor, const Color(0xFF0F4C81));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF14B8A6));
    expect(bootstrap.theme.accentColor, const Color(0xFFF59E0B));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFF7FAFC));
    expect(bootstrap.theme.textColor, const Color(0xFF111827));
    expect(bootstrap.theme.fontFamily, 'Sarabun');
  });

  test('mobile bootstrap accepts light-mode and typography font aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'mobileConfig': {
        'themeConfig': {
          'themes': {
            'light': {
              'colors': {
                'primary': '#155EEF',
                'surface': '#F8FAFC',
              },
              'fonts': {
                'body': {'family': 'LINE Seed Sans TH'},
              },
            },
          },
        },
      },
    });

    expect(bootstrap.theme.primaryColor, const Color(0xFF155EEF));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFF8FAFC));
    expect(bootstrap.theme.fontFamily, 'LINE Seed Sans TH');

    final listFontTheme = AppThemeTokens.fromJson({
      'themeTokens': {
        'typography': {
          'fontFamilies': [
            {'name': 'IBM Plex Sans Thai'},
          ],
        },
      },
    });

    expect(listFontTheme.fontFamily, 'IBM Plex Sans Thai');
  });

  test('mobile bootstrap deep-merges partner theme without blank overrides',
      () {
    final bootstrap = MobileBootstrap.fromJson({
      'brand': {
        'logo_url': 'https://partner.example/top-logo.webp',
      },
      'theme': {
        'colors': {
          'primary': '#102A43',
          'foreground': '#0F172A',
        },
        'font_family': 'Prompt',
      },
      'mobileConfig': {
        'brandConfig': {
          'logoUrl': '',
          'favicon': {'url': 'https://partner.example/mobile-icon.png'},
        },
        'themeConfig': {
          'colors': {
            'secondary': '#38BDF8',
            'primary': '',
          },
          'semantic': {'cta': '#F97316'},
          'fontFamily': '',
        },
      },
    });

    expect(bootstrap.brand.logoUrl, 'https://partner.example/top-logo.webp');
    expect(
      bootstrap.brand.faviconUrl,
      'https://partner.example/mobile-icon.png',
    );
    expect(bootstrap.theme.primaryColor, const Color(0xFF102A43));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF38BDF8));
    expect(bootstrap.theme.accentColor, const Color(0xFFF97316));
    expect(bootstrap.theme.textColor, const Color(0xFF0F172A));
    expect(bootstrap.theme.fontFamily, 'Prompt');
  });

  test('mobile bootstrap accepts nested partner brand asset aliases', () {
    final bootstrap = MobileBootstrap.fromJson({
      'brandConfig': {
        'assets': {
          'logo': {'assetUrl': '/storage/partner-logo.svg'},
          'favicon': {'publicUrl': 'https://partner.example/favicon.png'},
          'shareImage': {
            'fullUrl': 'https://partner.example/share-cover.webp',
          },
        },
      },
    });

    expect(bootstrap.brand.logoUrl, '/storage/partner-logo.svg');
    expect(bootstrap.brand.faviconUrl, 'https://partner.example/favicon.png');
    expect(
      bootstrap.brand.ogImageUrl,
      'https://partner.example/share-cover.webp',
    );
  });

  test('mobile bootstrap accepts appearance and branding config wrappers', () {
    final bootstrap = MobileBootstrap.fromJson({
      'appearance': {
        'brand': {
          'logo': '/storage/root-logo.webp',
        },
        'theme': {
          'colors': {
            'primary': {'value': '#1D4ED8'},
            'secondary': {'hex': '#0EA5E9'},
          },
        },
      },
      'mobileConfig': {
        'branding': {
          'logo': '/storage/mobile-logo.webp',
          'favicon': '/storage/mobile-icon.png',
          'shareImage': 'https://partner.example/share.webp',
        },
        'design': {
          'themeConfig': {
            'semantic': {
              'cta': {'cssValue': 'rgb(249, 115, 22)'},
              'surface': {'value': '#F8FAFC'},
              'onSurface': {'hexValue': '#0F172A'},
            },
            'font': {'family': 'Noto Sans Thai'},
          },
        },
      },
    });

    expect(bootstrap.brand.logoUrl, '/storage/mobile-logo.webp');
    expect(bootstrap.brand.faviconUrl, '/storage/mobile-icon.png');
    expect(bootstrap.brand.ogImageUrl, 'https://partner.example/share.webp');
    expect(bootstrap.theme.primaryColor, const Color(0xFF1D4ED8));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF0EA5E9));
    expect(bootstrap.theme.accentColor, const Color(0xFFF97316));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFF8FAFC));
    expect(bootstrap.theme.textColor, const Color(0xFF0F172A));
    expect(bootstrap.theme.fontFamily, 'Noto Sans Thai');
  });

  test('mobile bootstrap accepts css color formats for partner theme', () {
    final bootstrap = MobileBootstrap.fromJson({
      'theme': {
        'primary_color': '#0AF',
        'secondary_color': '#33669980',
        'accent_color': 'rgb(249, 115, 22)',
        'background_color': 'rgba(248, 250, 252, 0.9)',
        'text_color': 'hsl(222 47% 11% / 85%)',
      },
    });

    expect(bootstrap.theme.primaryColor, const Color(0xFF00AAFF));
    expect(bootstrap.theme.secondaryColor, const Color(0x80336699));
    expect(bootstrap.theme.accentColor, const Color(0xFFF97316));
    expect(bootstrap.theme.backgroundColor, const Color(0xE6F8FAFC));
    expect(bootstrap.theme.textColor, const Color(0xD90F1729));

    final legacyHex = AppThemeTokens.fromJson({
      'primaryColor': '0x80123456',
    });
    expect(legacyHex.primaryColor, const Color(0x80123456));

    final hslTheme = AppThemeTokens.fromJson({
      'primaryColor': 'hsl(210, 100%, 50%)',
      'secondaryColor': 'hsla(160, 84%, 39%, 0.8)',
      'accentColor': 'hsl(0.08turn 100% 50%)',
    });
    expect(hslTheme.primaryColor, const Color(0xFF0080FF));
    expect(hslTheme.secondaryColor, const Color(0xCC10B77F));
    expect(hslTheme.accentColor, const Color(0xFFFF7A00));
  });

  test('app theme fallback matches Nuxt customer visual tokens', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppTheme.appBlue);
    expect(theme.colorScheme.secondary, AppTheme.appSky);
    expect(theme.colorScheme.tertiary, AppTheme.appYellow);
    expect(theme.scaffoldBackgroundColor, AppTheme.appSheet);
    expect(
      AppTheme.primaryActionStart(AppTheme.appBlue),
      AppTheme.appActionStart,
    );
    expect(AppTheme.primaryActionEnd(AppTheme.appBlue), AppTheme.appActionEnd);
    expect(AppTheme.heroGradientStart(AppTheme.appBlue), AppTheme.appHeroStart);
    expect(AppTheme.heroGradientEnd(AppTheme.appBlue), AppTheme.appHeroEnd);
  });

  test('app theme keeps Nuxt blue identity with runtime color tokens', () {
    final theme = AppTheme.light(
      tokens: const AppThemeTokens(
        primaryColor: Color(0xFF10B981),
        secondaryColor: Color(0xFF22C55E),
        accentColor: Color(0xFF55B20E),
        backgroundColor: Color(0xFFFAFBFC),
        textColor: Color(0xFF111827),
        fontFamily: 'Prompt',
      ),
    );

    expect(theme.colorScheme.primary, AppTheme.appBlue);
    expect(theme.colorScheme.secondary, AppTheme.appSky);
    expect(theme.colorScheme.tertiary, AppTheme.appYellow);
    expect(theme.colorScheme.onSurface, const Color(0xFF111827));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFBFC));
    expect(theme.textTheme.bodyMedium?.color, const Color(0xFF111827));
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
  });

  test('app theme can opt into partner runtime color tokens', () {
    final theme = AppTheme.light(
      tokens: const AppThemeTokens(
        primaryColor: Color(0xFF123456),
        secondaryColor: Color(0xFF2255AA),
        accentColor: Color(0xFFFFAA00),
        backgroundColor: Color(0xFFFAFBFC),
        textColor: Color(0xFF111827),
        fontFamily: 'Prompt',
      ),
      useRuntimeBrandColors: true,
    );

    expect(theme.colorScheme.primary, const Color(0xFF123456));
    expect(theme.colorScheme.secondary, const Color(0xFF2255AA));
    expect(theme.colorScheme.tertiary, const Color(0xFFFFAA00));
    expect(theme.colorScheme.onSurface, const Color(0xFF111827));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFBFC));
    expect(theme.textTheme.bodyMedium?.color, const Color(0xFF111827));
  });
}

class _BootstrapApiClient extends ApiClient {
  _BootstrapApiClient(this.response)
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final Map<String, dynamic> response;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: response as T,
    );
  }
}

class _LocaleOverrideProbe extends ConsumerStatefulWidget {
  const _LocaleOverrideProbe({required this.observed});

  final List<String> observed;

  @override
  ConsumerState<_LocaleOverrideProbe> createState() =>
      _LocaleOverrideProbeState();
}

class _LocaleOverrideProbeState extends ConsumerState<_LocaleOverrideProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncCustomerLocaleFromBootstrap(ref, const Locale('en', 'US'));
      widget.observed.add(localeTag(ref.read(customerLocaleProvider)));

      setCustomerLocale(ref, const Locale('th', 'TH'));
      syncCustomerLocaleFromBootstrap(ref, const Locale('en', 'US'));
      widget.observed.add(localeTag(ref.read(customerLocaleProvider)));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
