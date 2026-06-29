import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_locale_controller.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
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
    expect(thai.profileBiometricStatusActive, 'เปิดใช้งาน');
    expect(english.profileBiometricStatusActive, 'Active');
    expect(thai.walletBalanceAfter('100.00 บาท'), 'คงเหลือ 100.00 บาท');
    expect(english.walletBalanceAfter('100.00 THB'), 'Balance 100.00 THB');
    expect(thai.topupTitle, 'เติมเงิน');
    expect(english.topupTitle, 'Top up');
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
    expect(thai.ticketClaimPayoutMethodTitle, 'ช่องทางขึ้นเงินรางวัล');
    expect(english.ticketClaimPayoutMethodTitle, 'Reward payout channel');
    expect(thai.ticketImagePreparing, 'รูปสลากกำลังเตรียมพร้อม');
    expect(english.ticketImagePreparing, 'Ticket image is being prepared');
    expect(thai.lotteryBuyTitle, 'ซื้อสลาก');
    expect(english.lotteryBuyTitle, 'Buy lottery');
    expect(thai.lotteryAddedToCart, 'เพิ่มสลากลงตะกร้าแล้ว');
    expect(english.lotteryAddedToCart, 'Ticket added to cart.');
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
    expect(thai.rewardClaimDetailTitle, 'รายละเอียดการขึ้นเงิน');
    expect(english.rewardClaimDetailTitle, 'Reward claim details');
    expect(thai.rewardClaimStatusPaid, 'โอนเงินสำเร็จ');
    expect(english.rewardClaimStatusPaid, 'Paid successfully');
    expect(thai.activityClaimsTitle, 'ประวัติขึ้นเงินรางวัลกิจกรรม');
    expect(english.activityClaimsTitle, 'Activity reward claim history');
    expect(thai.activityClaimRewardCashback, 'เงินคืนกิจกรรม');
    expect(english.activityClaimRewardCashback, 'Activity cashback');
    expect(thai.activityClaimStatusSubmitted, 'รอดำเนินการโอนเงิน');
    expect(english.activityClaimStatusSubmitted, 'Transfer pending');
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
    expect(bootstrap.brand.faviconUrl, 'https://partner.example/favicon.ico');
    expect(bootstrap.brand.ogImageUrl, 'https://partner.example/og.webp');
    expect(bootstrap.theme.primaryColor, const Color(0xFF123456));
    expect(bootstrap.theme.secondaryColor, const Color(0xFF2255AA));
    expect(bootstrap.theme.accentColor, const Color(0xFFFFAA00));
    expect(bootstrap.theme.backgroundColor, const Color(0xFFFAFBFC));
    expect(bootstrap.theme.textColor, const Color(0xFF111827));
    expect(bootstrap.theme.fontFamily, 'Prompt');
  });

  test('app theme applies partner runtime color tokens', () {
    final theme = AppTheme.light(
      tokens: const AppThemeTokens(
        primaryColor: Color(0xFF123456),
        secondaryColor: Color(0xFF2255AA),
        accentColor: Color(0xFFFFAA00),
        backgroundColor: Color(0xFFFAFBFC),
        textColor: Color(0xFF111827),
        fontFamily: 'Prompt',
      ),
    );

    expect(theme.colorScheme.primary, const Color(0xFF123456));
    expect(theme.colorScheme.secondary, const Color(0xFF2255AA));
    expect(theme.colorScheme.tertiary, const Color(0xFFFFAA00));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFBFC));
    expect(theme.textTheme.bodyMedium?.color, const Color(0xFF111827));
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
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
