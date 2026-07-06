import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import '../utils/formatters.dart';

class CustomerLocalizations {
  const CustomerLocalizations(
    this.locale, {
    this.runtimeValues = const <String, String>{},
  });

  static const delegate = _CustomerLocalizationsDelegate();
  static const fallback = CustomerLocalizations(fallbackCustomerLocale);

  final Locale locale;
  final Map<String, String> runtimeValues;

  static CustomerLocalizations of(BuildContext context) {
    return Localizations.of<CustomerLocalizations>(
          context,
          CustomerLocalizations,
        ) ??
        fallback;
  }

  String get bottomNavHome => _text('bottom_nav.home');
  String get bottomNavTickets => _text('bottom_nav.tickets');
  String get bottomNavWallet => _text('bottom_nav.wallet');
  String get bottomNavMore => _text('bottom_nav.more');
  String get commonLanguage => _text('common.language');
  String get commonThai => _text('common.thai');
  String get commonEnglish => _text('common.english');
  String get commonBahtSuffix => _text('common.money.baht_suffix');
  String get appAlertDefaultTitle => _text('app_alert.default_title');
  String get appAlertDefaultButton => _text('app_alert.default_button');
  String get appSplashPreparing => _text('app_splash.preparing');
  String get saleClosureAlertMessage => _text('sale_closure.alert_message');

  String get loginTitle => _text('auth.login.title');
  String get loginHeroBadge => _text('auth.login.hero_badge');
  String get loginHeroDescription => _text('auth.login.hero_description');
  String get loginFormTitle => _text('auth.login.form_title');
  String get loginFormDescription => _text('auth.login.form_description');
  String get loginIdentifierLabel => _text('auth.login.identifier_label');
  String get loginIdentifierHint => _text('auth.login.identifier_hint');
  String get loginPasswordLabel => _text('auth.login.password_label');
  String get loginPasswordHint => _text('auth.login.password_hint');
  String get loginSubmit => _text('auth.login.submit');
  String get loginSubmitting => _text('auth.login.submitting');
  String get loginRegister => _text('auth.login.register');
  String get loginRegisterPrompt => _text('auth.login.register_prompt');
  String get loginForgotPassword => _text('auth.login.forgot_password');
  String get loginRememberMe => _text('auth.login.remember_me');
  String get loginDivider => _text('auth.login.divider');
  String get loginShowPassword => _text('auth.login.show_password');
  String get loginHidePassword => _text('auth.login.hide_password');
  String socialLoginLabel(String providerLabel) {
    return _text('auth.login.social_continue').replaceAll(
      '{provider}',
      providerLabel,
    );
  }

  String socialLoginOpening(String providerLabel) {
    return _text('auth.login.social_opening').replaceAll(
      '{provider}',
      providerLabel,
    );
  }

  String get loginFailed => _text('auth.login.failed');
  String get socialLoginLinkMissing => _text('auth.login.social_link_missing');
  String get socialLoginFailed => _text('auth.login.social_failed');
  String get authFieldRequired => _text('auth.validation.required');
  String get authPhoneInvalid => _text('auth.validation.phone_invalid');
  String get authOtpInvalid => _text('auth.validation.otp_invalid');
  String get authConfirmPasswordRequired =>
      _text('auth.validation.confirm_password_required');
  String get authPasswordMismatch => _text('auth.validation.password_mismatch');
  String authOtpSentTo(String phone) {
    return _text('auth.otp.sent_to').replaceAll('{phone}', phone);
  }

  String authOtpResendIn(int seconds) {
    return _text('auth.otp.resend_in').replaceAll(
      '{seconds}',
      seconds.toString(),
    );
  }

  String get authOtpResend => _text('auth.otp.resend');
  String get authOtpLabel => _text('auth.otp.label');
  String get authOtpVerificationFailed => _text('auth.otp.verification_failed');
  String get registerTitle => _text('auth.register.title');
  String get registerHeroBadge => _text('auth.register.hero_badge');
  String get registerHeroDescription => _text('auth.register.hero_description');
  String get registerFormTitle => _text('auth.register.form_title');
  String get registerFormDescription => _text('auth.register.form_description');
  String get registerHeaderTitle => _text('auth.register.header_title');
  String get registerHeaderSubtitle => _text('auth.register.header_subtitle');
  String get registerFirstNameLabel => _text('auth.register.first_name');
  String get registerFirstNameHint => _text('auth.register.first_name_hint');
  String get registerLastNameLabel => _text('auth.register.last_name');
  String get registerLastNameHint => _text('auth.register.last_name_hint');
  String get registerPhoneLabel => _text('auth.register.phone');
  String get registerPhoneHint => _text('auth.register.phone_hint');
  String get registerPasswordLabel => _text('auth.register.password');
  String get registerPasswordHint => _text('auth.register.password_hint');
  String get registerConfirmPasswordLabel =>
      _text('auth.register.confirm_password');
  String get registerConfirmPasswordHint =>
      _text('auth.register.confirm_password_hint');
  String get registerShowPassword => _text('auth.register.show_password');
  String get registerHidePassword => _text('auth.register.hide_password');
  String get registerTerms => _text('auth.register.terms');
  String get registerOtpTitle => _text('auth.register.otp_title');
  String get registerOtpHint => _text('auth.register.otp_hint');
  String get registerSubmit => _text('auth.register.submit');
  String get registerSubmitWithOtp => _text('auth.register.submit_with_otp');
  String get registerSubmitting => _text('auth.register.submitting');
  String get registerLoginLink => _text('auth.register.login_link');
  String get registerLoginPrompt => _text('auth.register.login_prompt');
  String get registerTermsRequired => _text('auth.register.terms_required');
  String get registerFailed => _text('auth.register.failed');
  String get forgotPasswordTitle => _text('auth.forgot.title');
  String get forgotPasswordHeroTitle => _text('auth.forgot.hero_title');
  String get forgotPasswordHeroDescription =>
      _text('auth.forgot.hero_description');
  String get forgotPasswordTitlePhone => _text('auth.forgot.title_phone');
  String get forgotPasswordTitleOtp => _text('auth.forgot.title_otp');
  String get forgotPasswordTitlePassword => _text('auth.forgot.title_password');
  String get forgotPasswordTitleDone => _text('auth.forgot.title_done');
  String get forgotPasswordDescriptionPhone =>
      _text('auth.forgot.description_phone');
  String get forgotPasswordDescriptionOtp =>
      _text('auth.forgot.description_otp');
  String forgotPasswordDescriptionOtpSentTo(String phone) {
    return _text('auth.forgot.description_otp_sent_to').replaceAll(
      '{phone}',
      phone,
    );
  }

  String get forgotPasswordDescriptionPassword =>
      _text('auth.forgot.description_password');
  String get forgotPasswordDescriptionDone =>
      _text('auth.forgot.description_done');
  String get forgotPasswordButtonSendOtp =>
      _text('auth.forgot.button_send_otp');
  String get forgotPasswordButtonVerifyOtp =>
      _text('auth.forgot.button_verify_otp');
  String get forgotPasswordButtonSave =>
      _text('auth.forgot.button_save_password');
  String get forgotPasswordBackToLogin => _text('auth.forgot.back_to_login');
  String get forgotPasswordNewPassword => _text('auth.forgot.new_password');
  String get forgotPasswordConfirmNewPassword =>
      _text('auth.forgot.confirm_new_password');
  String get forgotPasswordPhoneHint => _text('auth.forgot.phone_hint');
  String get forgotPasswordOtpHint => _text('auth.forgot.otp_hint');
  String get forgotPasswordPasswordHint => _text('auth.forgot.password_hint');
  String get forgotPasswordConfirmPasswordHint =>
      _text('auth.forgot.confirm_password_hint');
  String get forgotPasswordSubmitting => _text('auth.forgot.submitting');
  String get forgotPasswordFailed => _text('auth.forgot.failed');
  String get forgotPasswordOtpProviderUnavailable =>
      _text('auth.forgot.otp_provider_unavailable');
  String get forgotPasswordDoneMessage => _text('auth.forgot.done_message');
  String get forgotPasswordLineTitle => _text('auth.forgot.line_title');
  String get forgotPasswordLineDescription =>
      _text('auth.forgot.line_description');
  String get forgotPasswordLineButton => _text('auth.forgot.line_button');
  String get forgotPasswordLineOpening => _text('auth.forgot.line_opening');
  String get forgotPasswordLineFailed => _text('auth.forgot.line_failed');
  String get resetPasswordTitle => _text('auth.reset.title');
  String get resetPasswordHeader => _text('auth.reset.header');
  String get resetPasswordLineDescription =>
      _text('auth.reset.line_description');
  String get resetPasswordLinkDescription =>
      _text('auth.reset.link_description');
  String get resetPasswordCardDescription =>
      _text('auth.reset.card_description');
  String get resetPasswordInvalidTitle => _text('auth.reset.invalid_title');
  String get resetPasswordInvalidMessage => _text('auth.reset.invalid_message');
  String get resetPasswordNewPassword => _text('auth.reset.new_password');
  String get resetPasswordNewPasswordHint =>
      _text('auth.reset.new_password_hint');
  String get resetPasswordConfirmNewPassword =>
      _text('auth.reset.confirm_new_password');
  String get resetPasswordConfirmNewPasswordHint =>
      _text('auth.reset.confirm_new_password_hint');
  String get resetPasswordShowPassword => _text('auth.reset.show_password');
  String get resetPasswordHidePassword => _text('auth.reset.hide_password');
  String get resetPasswordSave => _text('auth.reset.save');
  String get resetPasswordSubmitting => _text('auth.reset.submitting');
  String get resetPasswordPasswordRequired =>
      _text('auth.reset.password_required');
  String get resetPasswordSuccess => _text('auth.reset.success');
  String get resetPasswordExpired => _text('auth.reset.expired');
  String socialCallbackWaiting(String provider) {
    return _text('auth.social.callback.waiting').replaceAll(
      '{provider}',
      provider,
    );
  }

  String get socialCallbackTitle => _text('auth.social.callback.title');
  String socialCallbackMissingCode(String provider) {
    return _text('auth.social.callback.missing_code').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialCallbackFailed(String provider) {
    return _text('auth.social.callback.failed').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialCallbackConnectFailed(String provider) {
    return _text('auth.social.callback.connect_failed').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialLinkTitle(String provider) {
    return _text('auth.social.link.title').replaceAll('{provider}', provider);
  }

  String get socialLinkPhoneTitle => _text('auth.social.link.phone_title');
  String get socialLinkPhoneSubtitle =>
      _text('auth.social.link.phone_subtitle');
  String socialLinkHeroSubtitle(String provider) {
    return _text('auth.social.link.hero_subtitle').replaceAll(
      '{provider}',
      provider,
    );
  }

  String get socialLinkPasswordHint => _text('auth.social.link.password_hint');
  String get socialLinkConfirmPasswordHint =>
      _text('auth.social.link.confirm_password_hint');
  String get socialLinkSubmit => _text('auth.social.link.submit');
  String get socialLinkSubmitting => _text('auth.social.link.submitting');
  String socialLinkMissing(String provider) {
    return _text('auth.social.link.missing').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialLinkFailed(String provider) {
    return _text('auth.social.link.failed').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialProfileAccount(String provider) {
    return _text('auth.social.profile.account').replaceAll(
      '{provider}',
      provider,
    );
  }

  String socialProfileFallbackName(String provider) {
    return _text('auth.social.profile.fallback_name').replaceAll(
      '{provider}',
      provider,
    );
  }

  String get socialProfileReady => _text('auth.social.profile.ready');
  String get socialProfileStatus => _text('auth.social.profile.status');

  String get pinTitle => _text('pin.title');
  String get pinDescription => _text('pin.description');
  String get pinSetupTitle => _text('pin.setup.title');
  String get pinSetupConfirmTitle => _text('pin.setup.confirm_title');
  String get pinSetupDescription => _text('pin.setup.description');
  String get pinSetupConfirmDescription =>
      _text('pin.setup.confirm_description');
  String get pinSetupConfirmHelper => _text('pin.setup.confirm_helper');
  String get pinSetupSubmitting => _text('pin.setup.submitting');
  String get pinVerifying => _text('pin.verifying');
  String get pinSetupMismatch => _text('pin.setup.mismatch');
  String get pinSetupFailed => _text('pin.setup.failed');
  String get pinUseBiometric => _text('pin.use_biometric');
  String get pinBiometricReason => _text('pin.biometric_reason');
  String get pinBiometricUnavailable => _text('pin.biometric_unavailable');
  String get pinBiometricFailed => _text('pin.biometric_failed');
  String get pinForgot => _text('pin.forgot');
  String get pinInvalid => _text('pin.invalid');
  String get pinResetTitleRequest => _text('pin.reset.title_request');
  String get pinResetTitleOtp => _text('pin.reset.title_otp');
  String get pinResetTitlePin => _text('pin.reset.title_pin');
  String get pinResetTitleDone => _text('pin.reset.title_done');
  String get pinResetDescriptionRequest =>
      _text('pin.reset.description_request');
  String get pinResetDescriptionOtp => _text('pin.reset.description_otp');
  String get pinResetDescriptionPin => _text('pin.reset.description_pin');
  String get pinResetDescriptionConfirmPin =>
      _text('pin.reset.description_confirm_pin');
  String get pinResetDescriptionDone => _text('pin.reset.description_done');
  String get pinResetRequestInfo => _text('pin.reset.request_info');
  String get pinResetOtpLabel => _text('pin.reset.otp_label');
  String pinResetOtpSentTo(String phone) {
    return _text('pin.reset.otp_sent_to').replaceAll('{phone}', phone);
  }

  String pinResetResendIn(int seconds) {
    return _text('pin.reset.resend_in').replaceAll(
      '{seconds}',
      seconds.toString(),
    );
  }

  String get pinResetResend => _text('pin.reset.resend');
  String get pinResetNewPinLabel => _text('pin.reset.new_pin_label');
  String get pinResetConfirmPinLabel => _text('pin.reset.confirm_pin_label');
  String get pinResetPinMismatch => _text('pin.reset.pin_mismatch');
  String get pinResetDoneMessage => _text('pin.reset.done_message');
  String get pinResetBackToApp => _text('pin.reset.back_to_app');
  String get pinResetBackToPin => _text('pin.reset.back_to_pin');
  String get pinResetSubmitOtp => _text('pin.reset.submit_otp');
  String get pinResetSavePin => _text('pin.reset.save_pin');
  String get pinResetSendOtp => _text('pin.reset.send_otp');
  String get pinResetOtpRequired => _text('pin.reset.otp_required');
  String get pinResetPinRequired => _text('pin.reset.pin_required');
  String get pinResetFailed => _text('pin.reset.failed');
  String get pinResetSendFailed => _text('pin.reset.send_failed');
  String get pinResetOtpProviderUnavailable =>
      _text('pin.reset.otp_provider_unavailable');
  String get accountPhoneFallback => _text('common.account_phone');

  String get securityCaptureTitle => _text('security.capture.title');
  String get securityCaptureDescription =>
      _text('security.capture.description');
  String get securityUnlockAgain => _text('security.capture.unlock_again');

  String get commonViewAll => _text('common.view_all');
  String get commonRetry => _text('common.retry');
  String get commonCancel => _text('common.cancel');
  String get commonWalletBalance => _text('common.wallet_balance');
  String get commonNext => _text('common.next');
  String get commonConfirm => _text('common.confirm');
  String get commonLoadingData => _text('common.loading_data');
  String get commonLoadFailed => _text('common.load_failed');

  String customerRouteTitle(String key) => _text('routes.$key.title');
  String customerRouteDescription(String key) =>
      _text('routes.$key.description');
  String get customerRouteSensitive => _text('routes.badge.sensitive');
  String get customerRoutePublic => _text('routes.badge.public');
  String get customerRouteGroupStorefront => _text('routes.group.storefront');
  String get customerRouteGroupLottery => _text('routes.group.lottery');
  String get customerRouteGroupWallet => _text('routes.group.wallet');
  String get customerRouteGroupAccount => _text('routes.group.account');
  String get customerRouteGroupContent => _text('routes.group.content');
  String get customerRouteGroupSystem => _text('routes.group.system');

  String get homeTitle => _text('home.title');
  String get homeActivities => _text('home.activities');
  String get homeNews => _text('home.news');
  String get homeActionTopup => _text('home.action.topup');
  String get homeActionTickets => _text('home.action.tickets');
  String get homeActionClaim => _text('home.action.claim');
  String get homeActionHistory => _text('home.action.history');
  String get homeProductTitle => _text('home.product_title');
  String get homePriceAmount => _text('home.price.amount');
  String get homePriceUnit => _text('home.price.unit');
  String get homeSaleLabel => _text('home.sale.label');
  String get homeSaleAmount => _text('home.sale.amount');
  String get homeBuyLotteryTitle => _text('home.buy_lottery.title');
  String get homeBuyLotterySubtitle => _text('home.buy_lottery.subtitle');
  String get homeScanLotteryTitle => _text('home.scan_lottery.title');
  String get homeGuestTitle => _text('home.guest.title');
  String get homeGuestSubtitle => _text('home.guest.subtitle');
  String get homeResultsTitle => _text('home.results.title');
  String get homeResultsSubtitle => _text('home.results.subtitle');
  String get homeNewsTitle => _text('home.news_card.title');
  String get homeNewsSubtitle => _text('home.news_card.subtitle');
  String get resultTitle => _text('result.title');
  String get resultFullTitle => _text('result.full_title');
  String get resultLoading => _text('result.loading');
  String get resultHistoryTitle => _text('result.history_title');
  String get resultNoLatest => _text('result.no_latest');
  String get resultNoHistory => _text('result.no_history');
  String get resultNoAdditional => _text('result.no_additional');
  String get resultPayoutHint => _text('result.payout_hint');
  String get resultPendingDrawDate => _text('result.pending_draw_date');
  String get resultUnofficial => _text('result.unofficial');
  String resultDrawDate(String value) {
    return _text('result.draw_date').replaceAll('{date}', value);
  }

  String resultPrizeEach(String amount) {
    return _text('result.prize_each').replaceAll('{amount}', amount);
  }

  String resultRewardTitle(String slug, {String fallback = ''}) {
    final key = switch (slug) {
      'reward_1' => 'result.reward.reward_1',
      'reward_2' => 'result.reward.reward_2',
      'reward_3' => 'result.reward.reward_3',
      'reward_4' => 'result.reward.reward_4',
      'reward_5' => 'result.reward.reward_5',
      'reward_beside_1' => 'result.reward.reward_beside_1',
      'reward_three_digit_1' => 'result.reward.reward_three_digit_1',
      'reward_three_digit_2' => 'result.reward.reward_three_digit_2',
      'reward_two_digit' => 'result.reward.reward_two_digit',
      _ => '',
    };
    if (key.isEmpty) return fallback.isEmpty ? slug : fallback;
    return _text(key);
  }

  String get waitingResultTitle => _text('waiting_result.title');
  String get waitingResultSaleClosed => _text('waiting_result.sale_closed');
  String get waitingResultResolved => _text('waiting_result.resolved');
  String get waitingResultPending => _text('waiting_result.pending');
  String get waitingResultMyTickets => _text('waiting_result.my_tickets');
  String get waitingResultCheckResult => _text('waiting_result.check_result');
  String get waitingResultPlaceholder => _text('waiting_result.placeholder');
  String get waitingResultLiveTitle => _text('waiting_result.live.title');
  String get waitingResultLiveEmpty => _text('waiting_result.live.empty');
  String get waitingResultLiveOpen => _text('waiting_result.live.open');
  String get waitingResultLiveOpenFailed =>
      _text('waiting_result.live.open_failed');
  String maintenanceTitle(String siteName) {
    return _text('maintenance.title').replaceAll('{site}', siteName);
  }

  String get maintenanceFallbackTitle => _text('maintenance.fallback_title');
  String get maintenanceDefaultMessage => _text('maintenance.default_message');
  String maintenanceExpectedEnd(String date) {
    return _text('maintenance.expected_end').replaceAll('{date}', date);
  }

  String maintenanceSupport(String phone) {
    return _text('maintenance.support').replaceAll('{phone}', phone);
  }

  String maintenanceSupportEmail(String email) {
    return _text('maintenance.support_email').replaceAll('{email}', email);
  }

  String get maintenanceSupportOnline => _text('maintenance.support_online');

  String get maintenanceLoadingTitle => _text('maintenance.loading_title');
  String get maintenanceLoadingMessage => _text('maintenance.loading_message');
  String get accountSuspendedPermanent => _text('account_suspended.permanent');
  String get accountSuspendedTemporary => _text('account_suspended.temporary');
  String accountSuspendedUntil(String date) {
    return _text('account_suspended.until').replaceAll('{date}', date);
  }

  String get accountSuspendedTitle => _text('account_suspended.title');
  String get accountSuspendedKicker => _text('account_suspended.kicker');
  String get accountSuspendedMessage => _text('account_suspended.message');
  String get accountSuspendedReason => _text('account_suspended.reason');
  String get accountSuspendedNoReason => _text('account_suspended.no_reason');
  String get accountSuspendedDuration => _text('account_suspended.duration');
  String get accountSuspendedBackToLogin =>
      _text('account_suspended.back_to_login');
  String get accountSuspendedContactSupport =>
      _text('account_suspended.contact_support');
  String get accountSuspendedContactSupportOnline =>
      _text('account_suspended.contact_support_online');
  String accountSuspendedContactSupportWithPhone(String phone) {
    return _text('account_suspended.contact_support_with_phone')
        .replaceAll('{phone}', phone);
  }

  String accountSuspendedContactSupportWithEmail(String email) {
    return _text('account_suspended.contact_support_with_email')
        .replaceAll('{email}', email);
  }

  String get countdownTitle => _text('countdown.title');
  String get countdownWaitingTitle => _text('countdown.waiting_title');
  String get countdownOpensIn => _text('countdown.opens_in');
  String get countdownCurrentDrawFallback =>
      _text('countdown.current_draw_fallback');
  String countdownSaleOpensAt(String date) {
    return _text('countdown.sale_opens_at').replaceAll('{date}', date);
  }

  String get countdownLoadFailed => _text('countdown.load_failed');
  String get countdownDay => _text('countdown.unit.day');
  String get countdownHour => _text('countdown.unit.hour');
  String get countdownMinute => _text('countdown.unit.minute');
  String get countdownSecond => _text('countdown.unit.second');
  String get successTitle => _text('success.title');
  String get successLotteryProductLabel =>
      _text('success.lottery_product_label');
  String get successPurchaseTitle => _text('success.purchase_title');
  String get successPurchaseSubtitle => _text('success.purchase_subtitle');
  String get successViewTickets => _text('success.view_tickets');
  String get successSaveReceipt => _text('success.save_receipt');
  String get successReceiptSaved => _text('success.receipt_saved');
  String get successShareReceipt => _text('success.share_receipt');
  String get successReceiptShareStarted =>
      _text('success.receipt_share_started');
  String get successReceiptShareFailedCopied =>
      _text('success.receipt_share_failed_copied');
  String get successPaymentLoading => _text('success.payment_loading');
  String get successPaymentLoadFailed => _text('success.payment_load_failed');
  String get successTransactionAtLabel => _text('success.transaction_at_label');
  String get newsTitle => _text('news.title');
  String get newsDetailTitle => _text('news.detail_title');
  String get newsCategory => _text('news.category');
  String get newsFallbackTitle => _text('news.fallback_title');
  String get newsLoading => _text('news.loading');
  String get newsLoadFailedTitle => _text('news.load_failed.title');
  String get newsLoadFailedMessage => _text('news.load_failed.message');
  String get newsEmptyTitle => _text('news.empty.title');
  String get newsEmptyMessage => _text('news.empty.message');
  String get newsMissingTitle => _text('news.missing.title');
  String get newsMissingMessage => _text('news.missing.message');
  String get newsBackToList => _text('news.back_to_list');
  String get newsMissing => _text('news.missing');
  String get newsOpenFailed => _text('news.open_failed');
  String get newsModalClose => _text('news.modal.close');
  String get contentTermsTitle => _text('content.terms.title');
  String get contentTermsSiteFallback => _text('content.terms.site_fallback');
  String get contentTermsSectionTitle => _text('content.terms.section_title');
  String contentTermsDefaultContent(String siteName) {
    return _text('content.terms.default_content').replaceAll(
      '{site}',
      siteName,
    );
  }

  String get contentPrivacyTitle => _text('content.privacy.title');
  String get contentPrivacySectionTitle =>
      _text('content.privacy.section_title');
  String contentPrivacyHeroSubtitle(String siteName) {
    return _text('content.privacy.hero_subtitle').replaceAll(
      '{site}',
      siteName,
    );
  }

  String contentPrivacyDefaultContent(String siteName) {
    return _text('content.privacy.default_content').replaceAll(
      '{site}',
      siteName,
    );
  }

  String get contentPrivacyOpenPolicy => _text('content.privacy.open_policy');
  String get contentPrivacyOpenFailed => _text('content.privacy.open_failed');

  String get contentRewardTermsTitle => _text('content.reward_terms.title');
  String get contentRewardTermsHeroTitle =>
      _text('content.reward_terms.hero.title');
  String get contentRewardTermsHeroSubtitle =>
      _text('content.reward_terms.hero.subtitle');
  String get contentRewardTermsOfficeAbbr =>
      _text('content.reward_terms.office.abbr');
  String get contentRewardTermsOfficeName =>
      _text('content.reward_terms.office.name');
  String get contentRewardHeaderPrizeType =>
      _text('content.reward_terms.header.prize_type');
  String get contentRewardHeaderCount =>
      _text('content.reward_terms.header.count');
  String get contentRewardHeaderAmount =>
      _text('content.reward_terms.header.amount');
  String contentRewardRowTitle(String id) {
    return _text('content.reward_terms.row.$id.title');
  }

  String contentRewardRowCount(String id) {
    return _text('content.reward_terms.row.$id.count');
  }

  String contentRewardRowAmount(String id) {
    return _text('content.reward_terms.row.$id.amount');
  }

  String get contentKnowledgeTitle => _text('content.knowledge.title');
  String get contentKnowledgeSubtitle => _text('content.knowledge.subtitle');
  String get contentKnowledgeMoreInfo => _text('content.knowledge.more_info');
  String get contentKnowledgeContact => _text('content.knowledge.contact');
  String contentKnowledgeSectionTitle(String id) {
    return _text('content.knowledge.section.$id.title');
  }

  String contentKnowledgeSectionItem(String id, int index) {
    return _text('content.knowledge.section.$id.item_$index');
  }

  String get lotteryBuyTitle => _text('lottery.buy.title');
  String get lotteryAllTab => _text('lottery.tabs.all');
  String get lotteryStoresTab => _text('lottery.tabs.stores');
  String get lotteryCartTooltip => _text('lottery.cart.tooltip');
  String get lotterySearchHeroTitle => _text('lottery.search.hero_title');
  String get lotterySearchHeroSubtitle => _text('lottery.search.hero_subtitle');
  String get lotterySearchButton => _text('lottery.search.button');
  String get lotterySearchLoading => _text('lottery.search.loading');
  String get lotteryClearButton => _text('lottery.search.clear');
  String get lotteryStockTitle => _text('lottery.stock.title');
  String get lotteryStockSubtitle => _text('lottery.stock.subtitle');
  String get lotteryFilterAll => _text('lottery.filter.all');
  String get lotteryFilterDiscount => _text('lottery.filter.discount');
  String get lotteryFilterAccessibleStore =>
      _text('lottery.filter.accessible_store');
  String get lotteryFilterAgencyStore => _text('lottery.filter.agency_store');
  String get lotterySearchPageTitle => _text('lottery.search.page_title');
  String get lotterySearchCardTitle => _text('lottery.search.card_title');
  String get lotterySearchStoreCardTitle =>
      _text('lottery.search.store_card_title');
  String get lotteryNumberLabel => _text('lottery.search.number_label');
  String get lotterySearchAgain => _text('lottery.search.again');
  String get lotterySearchResultsTitle => _text('lottery.search.results_title');
  String get lotterySearchResultsSubtitle =>
      _text('lottery.search.results_subtitle');
  String get lotteryMoreTitle => _text('lottery.more.title');
  String get lotteryMoreSheetTitle => _text('lottery.more.sheet_title');
  String get lotteryMoreNumberPrefix => _text('lottery.more.number_prefix');
  String get lotteryMoreFallback => _text('lottery.more.fallback');
  String get lotteryMoreSubtitle => _text('lottery.more.subtitle');
  String get lotteryMoreListTitle => _text('lottery.more.list_title');
  String get lotteryShowNew => _text('lottery.stock.show_new');
  String get lotteryLoadingNew => _text('lottery.stock.loading_new');
  String lotteryRefreshCooldown(int seconds) {
    return _text('lottery.stock.refresh_cooldown').replaceAll(
      '{seconds}',
      seconds.toString(),
    );
  }

  String get lotteryLoadFailed => _text('lottery.stock.load_failed');
  String get lotteryNotFoundTitle => _text('lottery.stock.not_found.title');
  String get lotteryNotFoundMessage => _text('lottery.stock.not_found.message');
  String get lotteryAddedToCart => _text('lottery.stock.added_to_cart');
  String get lotteryRemovedFromCart => _text('lottery.stock.removed_from_cart');
  String get lotteryCartAction => _text('lottery.stock.cart_action');
  String get lotteryActionFailed => _text('lottery.stock.action_failed');
  String get lotteryReservationUnavailableTitle =>
      _text('lottery.stock.reservation_unavailable.title');
  String get lotteryReservationUnavailableMessage =>
      _text('lottery.stock.reservation_unavailable.message');
  String get lotteryReservationUnavailableAction =>
      _text('lottery.stock.reservation_unavailable.action');
  String get lotteryViewMore => _text('lottery.stock.view_more');
  String get lotterySelect => _text('lottery.stock.select');
  String get lotterySelecting => _text('lottery.stock.selecting');
  String get lotterySoldOut => _text('lottery.stock.sold_out');
  String get lotterySaleClosedTitle => _text('lottery.stock.sale_closed.title');
  String get lotterySaleClosedMessage =>
      _text('lottery.stock.sale_closed.message');
  String get lotterySaleClosedAction =>
      _text('lottery.stock.sale_closed.action');
  String get lotteryRemove => _text('lottery.stock.remove');
  String get lotteryRemoving => _text('lottery.stock.removing');

  String get cartTitle => _text('cart.title');
  String get cartReservedTitle => _text('cart.reserved_title');
  String get cartEmptySubtitle => _text('cart.empty_subtitle');
  String cartHeaderCount(int count) {
    return _text('cart.header_count').replaceAll('{count}', count.toString());
  }

  String cartSummary(int count, String total) {
    return _text('cart.summary')
        .replaceAll('{count}', count.toString())
        .replaceAll('{total}', total);
  }

  String cartDrawDate(String date) {
    return _text('cart.draw_date').replaceAll('{date}', date);
  }

  String get cartLoadFailedTitle => _text('cart.load_failed_title');
  String get cartLoading => _text('cart.loading');
  String get cartEmptyTitle => _text('cart.empty_title');
  String get cartEmptyMessage => _text('cart.empty_message');
  String get cartFindTickets => _text('cart.find_tickets');
  String get cartSelectionTitle => _text('cart.selection.title');
  String get cartSelectionCountLabel => _text('cart.selection.count_label');
  String get cartSelectionReview => _text('cart.selection.review');
  String get cartPurchaseLimitMessage => _text('cart.purchase_limit_message');
  String get cartAddMoreTickets => _text('cart.add_more_tickets');
  String get cartCheckout => _text('cart.checkout');
  String get cartGenericRetry => _text('cart.generic_retry');
  String cartRemoveGroupTitle(String number, int count) {
    final key = count > 1
        ? 'cart.remove_group_title.multiple'
        : 'cart.remove_group_title.single';
    return _text(key)
        .replaceAll('{number}', number)
        .replaceAll('{count}', count.toString());
  }

  String cartRemoveGroupMessage(int count) {
    return _text(
      count > 1
          ? 'cart.remove_group_message.multiple'
          : 'cart.remove_group_message.single',
    );
  }

  String get cartRemoveGroupConfirm => _text('cart.remove_group_confirm');
  String get cartRemoveGroupRemoving => _text('cart.remove_group_removing');
  String cartReservationTitle(int count) {
    return _text('cart.reservation_title').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String cartExpiresIn(int minutes) {
    return _text('cart.expires_in').replaceAll('{minutes}', minutes.toString());
  }

  String cartExpiresCountdown(String time) {
    return _text('cart.expires_countdown').replaceAll('{time}', time);
  }

  String get cartExpired => _text('cart.expired');
  String get cartExpiredReleaseMessage => _text('cart.expired_release_message');

  String get checkoutTitle => _text('checkout.title');
  String get checkoutSummaryTitle => _text('checkout.summary_title');
  String get checkoutTicketCount => _text('checkout.ticket_count');
  String get checkoutSummaryTotal => _text('checkout.summary_total');
  String get checkoutTotal => _text('checkout.total');
  String get checkoutWalletBalance => _text('checkout.wallet_balance');
  String get checkoutPaymentMethodTitle =>
      _text('checkout.payment_method_title');
  String get checkoutWalletFallbackName =>
      _text('checkout.wallet_fallback_name');
  String get checkoutWalletPaymentNote => _text('checkout.wallet_payment_note');
  String get checkoutWalletLoading => _text('checkout.wallet_loading');
  String get checkoutWalletLoadFailed => _text('checkout.wallet_load_failed');
  String get checkoutExternalPaymentName =>
      _text('checkout.external_payment.name');
  String get checkoutExternalPaymentSubtitle =>
      _text('checkout.external_payment.subtitle');
  String get checkoutExternalPaymentNote =>
      _text('checkout.external_payment.note');
  String get checkoutOpenPaymentFailed => _text('checkout.open_payment_failed');
  String get checkoutPendingTitle => _text('checkout.pending.title');
  String get checkoutPendingLoading => _text('checkout.pending.loading');
  String get checkoutPendingMessage => _text('checkout.pending.message');
  String get checkoutPendingPaidTitle => _text('checkout.pending.paid_title');
  String get checkoutPendingPaidMessage =>
      _text('checkout.pending.paid_message');
  String get checkoutPendingNoOrderTitle =>
      _text('checkout.pending.no_order_title');
  String get checkoutPendingNoOrderMessage =>
      _text('checkout.pending.no_order_message');
  String get checkoutPendingReferenceLabel =>
      _text('checkout.pending.reference_label');
  String get checkoutPendingStatusLabel =>
      _text('checkout.pending.status_label');
  String get checkoutPendingAmountLabel =>
      _text('checkout.pending.amount_label');
  String get checkoutPendingOpenPayment =>
      _text('checkout.pending.open_payment');
  String get checkoutPendingRefresh => _text('checkout.pending.refresh');
  String get checkoutPendingViewReceipt =>
      _text('checkout.pending.view_receipt');
  String get checkoutPendingStatusPending =>
      _text('checkout.pending.status.pending');
  String get checkoutPendingStatusPaid => _text('checkout.pending.status.paid');
  String get checkoutPendingStatusFailed =>
      _text('checkout.pending.status.failed');
  String get checkoutPendingStatusExpired =>
      _text('checkout.pending.status.expired');
  String get checkoutPendingStatusUnknown =>
      _text('checkout.pending.status.unknown');
  String checkoutPaymentTimer(String time) {
    return _text('checkout.payment_timer').replaceAll('{time}', time);
  }

  String get checkoutLoadFailedTitle => _text('checkout.load_failed_title');
  String get checkoutPreparing => _text('checkout.preparing');
  String get checkoutNoPaymentTitle => _text('checkout.no_payment_title');
  String get checkoutNoPaymentMessage => _text('checkout.no_payment_message');
  String get checkoutBackToBuy => _text('checkout.back_to_buy');
  String get checkoutInsufficientTitle => _text('checkout.insufficient.title');
  String get checkoutInsufficientSubtitle =>
      _text('checkout.insufficient.subtitle');
  String get checkoutSubmitting => _text('checkout.submitting');
  String get checkoutConfirm => _text('checkout.confirm');
  String get checkoutFailed => _text('checkout.failed');

  String get profileTitle => _text('profile.title');
  String get profileRefreshTooltip => _text('profile.refresh_tooltip');
  String get profileCustomerAccount => _text('profile.customer_account');
  String profileMemberCode(String value) {
    return _text('profile.member_code').replaceAll('{code}', value);
  }

  String get profileCopyMemberCode => _text('profile.copy_member_code');
  String get profileCopiedMemberCode => _text('profile.copied_member_code');
  String get profileLoading => _text('profile.loading');
  String get profileLoadFailed => _text('profile.load_failed');
  String get profileRefreshAgain => _text('profile.refresh_again');
  String get profileLanguageTitle => _text('profile.language.title');
  String get profileLanguageSubtitle => _text('profile.language.subtitle');
  String get profileLanguageSaveFailed => _text('profile.language.save_failed');
  String get profileSectionHistory => _text('profile.section.history');
  String get profileSectionRewardSettings =>
      _text('profile.section.reward_settings');
  String get profileSectionAbout => _text('profile.section.about');
  String get profileBadgeNew => _text('profile.badge.new');
  String get profileBadgeRecommended => _text('profile.badge.recommended');
  String get profileRewardBank => _text('profile.menu.reward_bank');
  String get profileHowToContact => _text('profile.menu.how_to_contact');
  String get profileRewardBankLoadFailed =>
      _text('profile.reward_bank.load_failed');
  String get profileRewardBankIncomplete =>
      _text('profile.reward_bank.incomplete');
  String get profileRewardBankSaved => _text('profile.reward_bank.saved');
  String get profileRewardBankSaveFailed =>
      _text('profile.reward_bank.save_failed');
  String get profileRewardBankPinInvalid =>
      _text('profile.reward_bank.pin_invalid');
  String get profileRewardBankPinLocked =>
      _text('profile.reward_bank.pin_locked');
  String get profileRewardBankPinRequired =>
      _text('profile.reward_bank.pin_required');
  String get profileRewardBankHeroTitle =>
      _text('profile.reward_bank.hero.title');
  String get profileRewardBankHeroSubtitle =>
      _text('profile.reward_bank.hero.subtitle');
  String get profileRewardBankFormTitle =>
      _text('profile.reward_bank.form.title');
  String get profileRewardBankFormDescription =>
      _text('profile.reward_bank.form.description');
  String get profileRewardBankBankLabel =>
      _text('profile.reward_bank.form.bank');
  List<String> get profileRewardBankOptions =>
      _text('profile.reward_bank.form.bank_options')
          .split('|')
          .where((bank) => bank.trim().isNotEmpty)
          .toList(growable: false);
  String get profileRewardBankAccountNameLabel =>
      _text('profile.reward_bank.form.account_name');
  String get profileRewardBankAccountNameHint =>
      _text('profile.reward_bank.form.account_name_hint');
  String get profileRewardBankAccountNumberLabel =>
      _text('profile.reward_bank.form.account_number');
  String get profileRewardBankAccountNumberHint =>
      _text('profile.reward_bank.form.account_number_hint');
  String get profileRewardBankSaveButton =>
      _text('profile.reward_bank.form.save');
  String get profileRewardBankPreviewEmptyTitle =>
      _text('profile.reward_bank.preview.empty_title');
  String get profileRewardBankPreviewEmptySubtitle =>
      _text('profile.reward_bank.preview.empty_subtitle');
  String get profileRewardBankPinTitle =>
      _text('profile.reward_bank.pin.title');
  String get profileRewardBankPinSubtitle =>
      _text('profile.reward_bank.pin.subtitle');
  String get profileAutoReward => _text('profile.menu.auto_reward');
  String get profileAutoRewardLoadFailed =>
      _text('profile.auto_reward.load_failed');
  String get profileAutoRewardSaveBankFirst =>
      _text('profile.auto_reward.save_bank_first');
  String get profileAutoRewardAddBankFirst =>
      _text('profile.auto_reward.add_bank_first');
  String get profileAutoRewardSaved => _text('profile.auto_reward.saved');
  String get profileAutoRewardSaveFailed =>
      _text('profile.auto_reward.save_failed');
  String get profileAutoRewardIntroSubtitle =>
      _text('profile.auto_reward.intro.subtitle');
  String get profileAutoRewardVisualCreditLabel =>
      _text('profile.auto_reward.visual.credit_label');
  String get profileAutoRewardVisualCreditAmount =>
      _text('profile.auto_reward.visual.credit_amount');
  String get profileAutoRewardVisualCreditCurrency =>
      _text('profile.auto_reward.visual.credit_currency');
  String get profileAutoRewardBenefitConvenient =>
      _text('profile.auto_reward.benefit.convenient');
  String get profileAutoRewardBenefitEasy =>
      _text('profile.auto_reward.benefit.easy');
  String profileAutoRewardBenefitFast(String reviewerName) {
    return _text('profile.auto_reward.benefit.fast').replaceAll(
      '{reviewer}',
      reviewerName.trim().isEmpty
          ? profileAutoRewardReviewerFallback
          : reviewerName.trim(),
    );
  }

  String get profileAutoRewardReviewerFallback =>
      _text('profile.auto_reward.reviewer_fallback');
  String get profileAutoRewardConditionsTitle =>
      _text('profile.auto_reward.conditions.title');
  String get profileAutoRewardConditionAutoClaim =>
      _text('profile.auto_reward.conditions.auto_claim');
  String get profileAutoRewardConditionFee =>
      _text('profile.auto_reward.conditions.fee');
  String get profileAutoRewardConditionChangeBefore =>
      _text('profile.auto_reward.conditions.change_before');
  String get profileAutoRewardConditionNoRetroactive =>
      _text('profile.auto_reward.conditions.no_retroactive');
  String get profileAutoRewardStartButton =>
      _text('profile.auto_reward.start_button');
  String get profileAutoRewardInfoTooltip =>
      _text('profile.auto_reward.info_tooltip');
  String get profileAutoRewardSelectTitle =>
      _text('profile.auto_reward.select.title');
  String profileAutoRewardSelectSubtitle(String reviewerName) {
    return _text('profile.auto_reward.select.subtitle').replaceAll(
      '{reviewer}',
      reviewerName.trim().isEmpty
          ? profileAutoRewardReviewerFallback
          : reviewerName.trim(),
    );
  }

  String get profileAutoRewardWalletTitle =>
      _text('profile.auto_reward.wallet.title');
  String get profileAutoRewardWalletSubtitle =>
      _text('profile.auto_reward.wallet.subtitle');
  String get profileAutoRewardBankTitle =>
      _text('profile.auto_reward.bank.title');
  String get profileAutoRewardBankMissingSubtitle =>
      _text('profile.auto_reward.bank.missing_subtitle');
  String get profileAutoRewardBankMissingHelper =>
      _text('profile.auto_reward.bank.missing_helper');
  String get profileAutoRewardPinTitle =>
      _text('profile.auto_reward.pin.title');
  String get profileAutoRewardPinSubtitle =>
      _text('profile.auto_reward.pin.subtitle');
  String get profileLineNotifications =>
      _text('profile.menu.line_notifications');
  String get profileLineHeroTitle =>
      _text('profile.line_notifications.hero.title');
  String get profileLineHeroSubtitle =>
      _text('profile.line_notifications.hero.subtitle');
  String get profileLineStoreUnavailableTitle =>
      _text('profile.line_notifications.store_unavailable.title');
  String get profileLineStoreUnavailableMessage =>
      _text('profile.line_notifications.store_unavailable.message');
  String get profileLineReconnect =>
      _text('profile.line_notifications.reconnect');
  String get profileLineConnect => _text('profile.line_notifications.connect');
  String get profileLineAddFriend =>
      _text('profile.line_notifications.add_friend');
  String get profileLineDisconnect =>
      _text('profile.line_notifications.disconnect');
  String get profileLineConnectFailed =>
      _text('profile.line_notifications.connect_failed');
  String get profileLineSaveFailed =>
      _text('profile.line_notifications.save_failed');
  String get profileLineDisconnected =>
      _text('profile.line_notifications.disconnected');
  String get profileLineDisconnectFailed =>
      _text('profile.line_notifications.disconnect_failed');
  String get profileLineMissingUrl =>
      _text('profile.line_notifications.missing_url');
  String get profileLineConnectedTitle =>
      _text('profile.line_notifications.connected_title');
  String get profileLineNotConnectedTitle =>
      _text('profile.line_notifications.not_connected_title');
  String get profileLineConnectOnce =>
      _text('profile.line_notifications.connect_once');
  String get profileLineReady => _text('profile.line_notifications.ready');
  String get profileLineNotLinked =>
      _text('profile.line_notifications.not_linked');
  String get profileLineNotificationStatus =>
      _text('profile.line_notifications.status.notification');
  String get profileLineNotificationOn =>
      _text('profile.line_notifications.status.notification_on');
  String get profileLineNotificationOff =>
      _text('profile.line_notifications.status.notification_off');
  String get profileLineFriendStatus =>
      _text('profile.line_notifications.status.friend');
  String get profileLineFriendAdded =>
      _text('profile.line_notifications.status.friend_added');
  String get profileLineFriendMissing =>
      _text('profile.line_notifications.status.friend_missing');
  String get profileLineToggleTitle =>
      _text('profile.line_notifications.toggle.title');
  String get profileLineToggleSubtitle =>
      _text('profile.line_notifications.toggle.subtitle');
  String get profileLineEventsTitle =>
      _text('profile.line_notifications.events.title');
  String get profileLineEventsSubtitle =>
      _text('profile.line_notifications.events.subtitle');
  String get profileLineEventTopup =>
      _text('profile.line_notifications.events.topup');
  String get profileLineEventOrder =>
      _text('profile.line_notifications.events.order');
  String get profileLineEventActivity =>
      _text('profile.line_notifications.events.activity');
  String get profileLineEventReward =>
      _text('profile.line_notifications.events.reward');
  String get profileLineLoadFailed =>
      _text('profile.line_notifications.load_failed');
  String get profileBiometrics => _text('profile.menu.biometrics');
  String get profileBiometricEnabled => _text('profile.biometric.enabled');
  String get profileBiometricEnableFailed =>
      _text('profile.biometric.enable_failed');
  String get profileBiometricRevokeDialogTitle =>
      _text('profile.biometric.revoke_dialog.title');
  String profileBiometricRevokeDialogMessage(String device) {
    return _text('profile.biometric.revoke_dialog.message').replaceAll(
      '{device}',
      device,
    );
  }

  String get profileBiometricRevoked => _text('profile.biometric.revoked');
  String get profileBiometricRevokeFailed =>
      _text('profile.biometric.revoke_failed');
  String get profileBiometricPinDialogTitle =>
      _text('profile.biometric.pin_dialog.title');
  String get profileBiometricSetupReason =>
      _text('profile.biometric.setup_reason');
  String get profileBiometricDeviceNameIos =>
      _text('profile.biometric.device_name.ios');
  String get profileBiometricDeviceNameAndroid =>
      _text('profile.biometric.device_name.android');
  String get profileBiometricDeviceNameFallback =>
      _text('profile.biometric.device_name.fallback');
  String get profileBiometricIntroTitle =>
      _text('profile.biometric.intro.title');
  String get profileBiometricIntroSubtitle =>
      _text('profile.biometric.intro.subtitle');
  String get profileBiometricUnavailableTitle =>
      _text('profile.biometric.enable.unavailable_title');
  String get profileBiometricEnableTitle =>
      _text('profile.biometric.enable.title');
  String get profileBiometricUnavailableMessage =>
      _text('profile.biometric.enable.unavailable_message');
  String get profileBiometricEnableMessage =>
      _text('profile.biometric.enable.message');
  String get profileBiometricSaving => _text('profile.biometric.enable.saving');
  String get profileBiometricEnableButton =>
      _text('profile.biometric.enable.button');
  String get profileBiometricEmptyTitle =>
      _text('profile.biometric.empty.title');
  String get profileBiometricEmptyMessage =>
      _text('profile.biometric.empty.message');
  String get profileBiometricActiveDevices =>
      _text('profile.biometric.active_devices');
  String get profileBiometricNoActiveDevices =>
      _text('profile.biometric.no_active_devices');
  String get profileBiometricRevokedDevices =>
      _text('profile.biometric.revoked_devices');
  String get profileBiometricStatusActive =>
      _text('profile.biometric.status.active');
  String get profileBiometricStatusRevoked =>
      _text('profile.biometric.status.revoked');
  String get profileBiometricCurrentDevice =>
      _text('profile.biometric.status.current_device');
  String get profileBiometricNeverUsed => _text('profile.biometric.never_used');
  String get profileBiometricRegisteredLabel =>
      _text('profile.biometric.meta.registered');
  String get profileBiometricLastUsedLabel =>
      _text('profile.biometric.meta.last_used');
  String get profileBiometricRevokeDevice =>
      _text('profile.biometric.revoke_device');
  String get profileBiometricLoadFailed =>
      _text('profile.biometric.load_failed');
  String get profilePurchaseHistory => _text('profile.menu.purchase_history');
  String get profileNewsAll => _text('profile.menu.news_all');
  String get profileTerms => _text('profile.menu.terms');
  String get profilePrivacyPolicy => _text('profile.menu.privacy_policy');
  String get profileAccountDeletion => _text('profile.menu.account_deletion');
  String get profileLogout => _text('profile.logout');

  String get accountDeletionTitle => _text('account_deletion.title');
  String get accountDeletionHeroTitle => _text('account_deletion.hero.title');
  String get accountDeletionHeroSubtitle =>
      _text('account_deletion.hero.subtitle');
  String get accountDeletionBeforeTitle =>
      _text('account_deletion.before.title');
  String get accountDeletionBeforeBody => _text('account_deletion.before.body');
  String get accountDeletionRequestTitle =>
      _text('account_deletion.request.title');
  String get accountDeletionRequestBody =>
      _text('account_deletion.request.body');
  String get accountDeletionOpenRequest =>
      _text('account_deletion.open_request');
  String get accountDeletionContactSupport =>
      _text('account_deletion.contact_support');
  String get accountDeletionContactSupportOnline =>
      _text('account_deletion.contact_support_online');
  String accountDeletionContactSupportWithPhone(String phone) {
    return _text('account_deletion.contact_support_with_phone')
        .replaceAll('{phone}', phone);
  }

  String accountDeletionContactSupportWithEmail(String email) {
    return _text('account_deletion.contact_support_with_email')
        .replaceAll('{email}', email);
  }

  String get accountDeletionNoOnlineRequest =>
      _text('account_deletion.no_online_request');
  String get accountDeletionLaunchFailed =>
      _text('account_deletion.launch_failed');

  String get walletTitle => _text('wallet.title');
  String get walletBalanceLoading => _text('wallet.balance.loading');
  String get walletRecentLedger => _text('wallet.recent_ledger');
  String get walletRecentLedgerSubtitle =>
      _text('wallet.recent_ledger.subtitle');
  String get walletRefreshTooltip => _text('wallet.refresh_tooltip');
  String get walletLedgerLoading => _text('wallet.ledger.loading');
  String get walletLedgerLoadFailed => _text('wallet.ledger.load_failed');
  String get walletLedgerLoadFailedMessage =>
      _text('wallet.ledger.load_failed_message');
  String get walletEmptyLedgerTitle => _text('wallet.empty_ledger.title');
  String get walletEmptyLedgerSubtitle => _text('wallet.empty_ledger.subtitle');
  String walletBalanceAfter(String amount) {
    return _text('wallet.balance_after').replaceAll('{amount}', amount);
  }

  String get walletLedgerTopup => _text('wallet.ledger.topup');
  String get walletLedgerOrder => _text('wallet.ledger.order');
  String get walletLedgerRewardClaim => _text('wallet.ledger.reward_claim');
  String get walletLedgerActivityReward =>
      _text('wallet.ledger.activity_reward');
  String get walletLedgerActivityCashback =>
      _text('wallet.ledger.activity_cashback');
  String get walletLedgerOrderRefund => _text('wallet.ledger.order_refund');
  String get walletLedgerDebit => _text('wallet.ledger.debit');
  String get walletLedgerCredit => _text('wallet.ledger.credit');
  String get walletLedgerGeneric => _text('wallet.ledger.generic');
  String get walletLedgerSuccess => _text('wallet.ledger.success');
  String walletLedgerReference(String reference) {
    return _text('wallet.ledger.reference').replaceAll(
      '{reference}',
      reference,
    );
  }

  String get topupTitle => _text('topup.title');
  String get topupLoading => _text('topup.loading');
  String get topupLoadingMessage => _text('topup.loading_message');
  String get topupLoadFailed => _text('topup.load_failed');
  String get topupLoadFailedMessage => _text('topup.load_failed_message');
  String get topupHeaderTitle => _text('topup.header.title');
  String get topupHeaderSubtitle => _text('topup.header.subtitle');
  String get topupHistoryTooltip => _text('topup.history_tooltip');
  String get topupWaitingTitle => _text('topup.waiting.title');
  String get topupWaitingAmountLabel => _text('topup.waiting.amount_label');
  String get topupWaitingQrTitle => _text('topup.waiting.qr_title');
  String get topupWaitingSlipTitle => _text('topup.waiting.slip_title');
  String get topupWaitingSlipPending => _text('topup.waiting.slip_pending');
  String get topupWaitingSlipSent => _text('topup.waiting.slip_sent');
  String get topupWaitingSlipPendingDescription =>
      _text('topup.waiting.slip_pending_description');
  String get topupWaitingSlipSentDescription =>
      _text('topup.waiting.slip_sent_description');
  String topupReference(String reference) {
    return _text('topup.reference').replaceAll('{reference}', reference);
  }

  String get topupQrSlipInstruction => _text('topup.qr_slip_instruction');
  String get topupOpenPayment => _text('topup.open_payment');
  String get topupOpenPaymentFailed => _text('topup.open_payment_failed');
  String get topupNeedsSlip => _text('topup.needs_slip');
  String get topupUploadSlip => _text('topup.upload_slip');
  String get topupUploadNewSlip => _text('topup.upload_new_slip');
  String get topupUploadingSlip => _text('topup.uploading_slip');
  String get topupCancelWaiting => _text('topup.cancel_waiting');
  String get topupCancelConfirmTitle => _text('topup.cancel_confirm.title');
  String topupCancelConfirmMessage(String reference) {
    return _text('topup.cancel_confirm.message').replaceAll(
      '{reference}',
      reference,
    );
  }

  String get topupCancelConfirmAmountLabel =>
      _text('topup.cancel_confirm.amount_label');
  String get topupCancelConfirmKeep => _text('topup.cancel_confirm.keep');
  String get topupCancelConfirmConfirm => _text('topup.cancel_confirm.confirm');
  String get topupCancelConfirmCancelling =>
      _text('topup.cancel_confirm.cancelling');
  String get topupChooseChannel => _text('topup.choose_channel');
  String get topupBlockingWaitingTitle => _text('topup.blocking_waiting.title');
  String get topupBlockingWaitingMessage =>
      _text('topup.blocking_waiting.message');
  String get topupAmountLabel => _text('topup.amount_label');
  String get topupBahtSuffix => _text('topup.baht_suffix');
  String get topupCreateQr => _text('topup.submit.qr');
  String get topupCreateCreditQr => _text('topup.submit.credit_qr');
  String get topupCreateBankTransfer => _text('topup.submit.bank_transfer');
  String get topupCreatingQr => _text('topup.submit.creating_qr');
  String get topupSubmittingBankTransfer =>
      _text('topup.submit.submitting_bank_transfer');
  String get topupBankSlipTitle => _text('topup.bank_slip.title');
  String get topupBankSlipDescription => _text('topup.bank_slip.description');
  String get topupBankSlipAttach => _text('topup.bank_slip.attach');
  String get topupBankSlipChange => _text('topup.bank_slip.change');
  String get topupBankSlipRemove => _text('topup.bank_slip.remove');
  String get topupBankSlipFileLabel => _text('topup.bank_slip.file_label');
  String get topupBankSlipTransferAt => _text('topup.bank_slip.transfer_at');
  String get topupBankSlipTransferAtUnset =>
      _text('topup.bank_slip.transfer_at_unset');
  String get topupBankSlipRequired => _text('topup.bank_slip.required');
  String get topupBankTransferSubmitted =>
      _text('topup.bank_transfer_submitted');
  String get topupDeferredSlipQr => _text('topup.deferred_slip.qr');
  String get topupDeferredSlipCredit => _text('topup.deferred_slip.credit');
  String get topupChannelQrLabel => _text('topup.channel.qr.label');
  String get topupChannelQrDescription => _text('topup.channel.qr.description');
  String get topupChannelCreditLabel => _text('topup.channel.credit.label');
  String get topupChannelCreditDescription =>
      _text('topup.channel.credit.description');
  String get topupChannelBankLabel => _text('topup.channel.bank.label');
  String get topupChannelBankDescription =>
      _text('topup.channel.bank.description');
  String get topupChannelDisabled => _text('topup.channel.disabled');
  String get topupBankAccountFallback => _text('topup.bank_account_fallback');
  String get topupStatusPendingPayment => _text('topup.status.pending_payment');
  String get topupStatusPendingReview => _text('topup.status.pending_review');
  String get topupStatusApproved => _text('topup.status.approved');
  String get topupStatusRejected => _text('topup.status.rejected');
  String get topupStatusCancelled => _text('topup.status.cancelled');
  String get topupStatusExpired => _text('topup.status.expired');
  String get topupStatusUnknown => _text('topup.status.unknown');
  String get topupAmountRequired => _text('topup.error.amount_required');
  String topupMinimumAmount(String channel, String amount) {
    return _text('topup.error.minimum_amount')
        .replaceAll('{channel}', channel)
        .replaceAll('{amount}', amount);
  }

  String topupMinimumHint(String amount) {
    return _text('topup.minimum_hint').replaceAll('{amount}', amount);
  }

  String get topupCreated => _text('topup.created');
  String get topupCreateFailed => _text('topup.create_failed');
  String get topupCancelled => _text('topup.cancelled');
  String get topupCancelFailed => _text('topup.cancel_failed');
  String get topupSlipTooLarge => _text('topup.slip_too_large');
  String get topupSlipUploaded => _text('topup.slip_uploaded');
  String get topupSlipUploadFailed => _text('topup.slip_upload_failed');
  String get topupHistoryTitle => _text('topup.history.title');
  String get topupHistoryLoading => _text('topup.history.loading');
  String get topupHistoryLoadFailed => _text('topup.history.load_failed');
  String get topupHistoryHeaderTitle => _text('topup.history.header.title');
  String get topupHistoryHeaderSubtitle =>
      _text('topup.history.header.subtitle');
  String get topupHistoryItemTitle => _text('topup.history.item_title');
  String topupHistoryReference(String reference, String channel, String date) {
    return _text('topup.history.reference')
        .replaceAll('{reference}', reference)
        .replaceAll('{channel}', channel)
        .replaceAll('{date}', date);
  }

  String topupHistoryBonus(String amount) {
    return _text('topup.history.bonus').replaceAll('{amount}', amount);
  }

  String get topupHistoryEmptyTitle => _text('topup.history.empty.title');
  String get topupHistoryEmptySubtitle => _text('topup.history.empty.subtitle');

  String get rewardClaimsTitle => _text('reward_claims.title');
  String get rewardClaimsHeaderTitle => _text('reward_claims.header.title');
  String get rewardClaimsHeaderSubtitle =>
      _text('reward_claims.header.subtitle');
  String get rewardClaimsTicketsTooltip =>
      _text('reward_claims.tickets_tooltip');
  String get rewardClaimsPrizeTitle => _text('reward_claims.prize_title');
  String get rewardClaimsLoading => _text('reward_claims.loading');
  String get rewardClaimsLoadFailed => _text('reward_claims.load_failed');
  String get rewardClaimsLoadMoreFailed =>
      _text('reward_claims.load_more_failed');
  String get rewardClaimsLoadingMore => _text('reward_claims.loading_more');
  String get rewardClaimsLoadMore => _text('reward_claims.load_more');
  String get rewardClaimsEmptyTitle => _text('reward_claims.empty.title');
  String get rewardClaimsEmptySubtitle => _text('reward_claims.empty.subtitle');
  String get rewardClaimsViewWinningTickets =>
      _text('reward_claims.view_winning_tickets');
  String get rewardClaimDetailTitle => _text('reward_claims.detail.title');
  String get rewardClaimDetailLoading => _text('reward_claims.detail.loading');
  String get rewardClaimDetailLoadFailed =>
      _text('reward_claims.detail.load_failed');
  String get rewardClaimMethodLabel => _text('reward_claims.detail.method');
  String get rewardClaimManualMethod =>
      _text('reward_claims.detail.manual_method');
  String get rewardClaimPayoutChannelLabel =>
      _text('reward_claims.detail.payout_channel');
  String get rewardClaimStatusLabel => _text('reward_claims.detail.status');
  String get rewardClaimDrawDateLabel =>
      _text('reward_claims.detail.draw_date');
  String get rewardClaimTaxLabel => _text('reward_claims.detail.tax');
  String get rewardClaimFeeLabel => _text('reward_claims.detail.fee');
  String rewardClaimWaived(String amount) {
    return _text('reward_claims.detail.waived').replaceAll('{amount}', amount);
  }

  String get rewardClaimZeroBaht => _text('reward_claims.detail.zero_baht');
  String get rewardClaimBankFallback =>
      _text('reward_claims.detail.bank_fallback');
  String get rewardClaimWalletFallback =>
      _text('reward_claims.detail.wallet_fallback');
  String get rewardClaimCustomerFallback =>
      _text('reward_claims.customer_fallback');
  String rewardClaimPayoutBank(String bankName) {
    return _text('reward_claims.payout.bank').replaceAll(
      '{bank}',
      bankName,
    );
  }

  String rewardClaimPayoutWallet(String walletName) {
    return _text('reward_claims.payout.wallet').replaceAll(
      '{wallet}',
      walletName,
    );
  }

  String get rewardClaimBankPrefix => _text('reward_claims.payout.bank_prefix');

  String rewardClaimPrizeMore(String prizeName, int count) {
    return _text('reward_claims.prize.more')
        .replaceAll('{prize}', prizeName)
        .replaceAll('{count}', count.toString());
  }

  String rewardClaimPrizeType(String type) {
    final key = switch (type) {
      'first_prize' => 'reward_claims.prize.first_prize',
      'near_first_prize' => 'reward_claims.prize.near_first_prize',
      'second_prize' => 'reward_claims.prize.second_prize',
      'third_prize' => 'reward_claims.prize.third_prize',
      'fourth_prize' => 'reward_claims.prize.fourth_prize',
      'fifth_prize' => 'reward_claims.prize.fifth_prize',
      'front3' => 'reward_claims.prize.front3',
      'back3' => 'reward_claims.prize.back3',
      'back2' => 'reward_claims.prize.back2',
      _ => 'reward_claims.prize.fallback',
    };
    return _text(key);
  }

  String get rewardClaimStatusPaid => _text('reward_claims.status.paid');
  String get rewardClaimStatusRejected =>
      _text('reward_claims.status.rejected');
  String get rewardClaimStatusCancelled =>
      _text('reward_claims.status.cancelled');
  String get rewardClaimStatusApproved =>
      _text('reward_claims.status.approved');
  String get rewardClaimStatusSubmitted =>
      _text('reward_claims.status.submitted');
  String get rewardClaimNotePaid => _text('reward_claims.note.paid');
  String get rewardClaimNoteRejected => _text('reward_claims.note.rejected');
  String get rewardClaimNoteCancelled => _text('reward_claims.note.cancelled');
  String get rewardClaimNoteApproved => _text('reward_claims.note.approved');
  String get rewardClaimNoteSubmitted => _text('reward_claims.note.submitted');
  String get rewardClaimEmptyDetail => _text('reward_claims.detail.empty');

  String get activityClaimsTitle => _text('activity_claims.title');
  String get activityClaimsHeaderTitle => _text('activity_claims.header.title');
  String get activityClaimsHeaderSubtitle =>
      _text('activity_claims.header.subtitle');
  String get activityClaimsActivitiesTooltip =>
      _text('activity_claims.activities_tooltip');
  String get activityClaimsPrizeTitle => _text('activity_claims.prize_title');
  String get activityClaimsLoading => _text('activity_claims.loading');
  String get activityClaimsLoadFailed => _text('activity_claims.load_failed');
  String get activityClaimsLoadMoreFailed =>
      _text('activity_claims.load_more_failed');
  String get activityClaimsEmptyTitle => _text('activity_claims.empty.title');
  String get activityClaimsEmptySubtitle =>
      _text('activity_claims.empty.subtitle');
  String get activityClaimsViewActivities =>
      _text('activity_claims.view_activities');
  String get activityClaimDetailTitle => _text('activity_claims.detail.title');
  String get activityClaimDetailLoading =>
      _text('activity_claims.detail.loading');
  String get activityClaimDetailLoadFailed =>
      _text('activity_claims.detail.load_failed');
  String get activityClaimRewardTitle =>
      _text('activity_claims.detail.reward_title');
  String get activityClaimActivityFallback =>
      _text('activity_claims.activity_fallback');
  String get activityClaimCustomerFallback =>
      _text('activity_claims.customer_fallback');
  String get activityClaimRecipientLabel =>
      _text('activity_claims.detail.recipient');
  String get activityClaimPayoutChannelLabel =>
      _text('activity_claims.detail.payout_channel');
  String get activityClaimPayoutMethodLabel =>
      _text('activity_claims.detail.payout_method');
  String get activityClaimStatusLabel => _text('activity_claims.detail.status');
  String get activityClaimActivityLabel =>
      _text('activity_claims.detail.activity');
  String get activityClaimRewardTypeLabel =>
      _text('activity_claims.detail.reward_type');
  String get activityClaimReferenceLabel =>
      _text('activity_claims.detail.reference');
  String get activityClaimSubmittedAtLabel =>
      _text('activity_claims.detail.submitted_at');
  String get activityClaimPaidAtLabel =>
      _text('activity_claims.detail.paid_at');
  String get activityClaimReviewedAtLabel =>
      _text('activity_claims.detail.reviewed_at');
  String get activityClaimCustomerNoteTitle =>
      _text('activity_claims.detail.customer_note');
  String get activityClaimAdminNoteTitle =>
      _text('activity_claims.detail.admin_note');
  String get activityClaimBankTransfer =>
      _text('activity_claims.payout.bank_transfer');
  String get activityClaimWalletCredit =>
      _text('activity_claims.payout.wallet_credit');
  String get activityClaimBankFallback =>
      _text('activity_claims.payout.bank_fallback');
  String get activityClaimWalletFallback =>
      _text('activity_claims.payout.wallet_fallback');
  String get activityClaimBankPrefix =>
      _text('activity_claims.payout.bank_prefix');
  String activityClaimBankSummary(String bankName) {
    return _text('activity_claims.payout.bank_summary').replaceAll(
      '{bank}',
      bankName,
    );
  }

  String activityClaimWalletSummary(String walletName) {
    return _text('activity_claims.payout.wallet_summary').replaceAll(
      '{wallet}',
      walletName,
    );
  }

  String get activityClaimAmountLabel => _text('activity_claims.detail.amount');
  String get activityClaimNetAmountLabel =>
      _text('activity_claims.detail.net_amount');
  String get activityClaimEmptyDetail => _text('activity_claims.detail.empty');
  String get activityClaimStatusPaid => _text('activity_claims.status.paid');
  String get activityClaimStatusRejected =>
      _text('activity_claims.status.rejected');
  String get activityClaimStatusCancelled =>
      _text('activity_claims.status.cancelled');
  String get activityClaimStatusApproved =>
      _text('activity_claims.status.approved');
  String get activityClaimStatusSubmitted =>
      _text('activity_claims.status.submitted');
  String get activityClaimNotePaid => _text('activity_claims.note.paid');
  String get activityClaimNoteRejected =>
      _text('activity_claims.note.rejected');
  String get activityClaimNoteCancelled =>
      _text('activity_claims.note.cancelled');
  String get activityClaimNoteApproved =>
      _text('activity_claims.note.approved');
  String activityClaimNoteSubmitted(String reviewerName) {
    return _text('activity_claims.note.submitted').replaceAll(
      '{reviewer}',
      reviewerName,
    );
  }

  String get activityClaimReviewerFallback =>
      _text('activity_claims.reviewer_fallback');
  String get activityClaimRewardCashback =>
      _text('activity_claims.reward.cashback');
  String get activityClaimRewardFirstPrizeLast2 =>
      _text('activity_claims.reward.first_prize_last2');
  String get activityClaimRewardFirstPrizeLast3 =>
      _text('activity_claims.reward.first_prize_last3');
  String get activityClaimRewardLast2 => _text('activity_claims.reward.last2');
  String get activityClaimRewardFallback =>
      _text('activity_claims.reward.fallback');
  String get activitiesHistoryButton => _text('activities.history_button');
  String get activitiesHistoryTitle => _text('activities.history_title');
  String get activitiesHistoryHint => _text('activities.history_hint');
  String get activitiesHistorySelectLabel =>
      _text('activities.history_select_label');
  String get activitiesHistoryNoGames => _text('activities.history_no_games');
  String get activitiesBackToCurrent => _text('activities.back_to_current');
  String get activitiesLoading => _text('activities.loading');
  String get activitiesHistoryLoading => _text('activities.history_loading');
  String get activitiesLoadFailed => _text('activities.load_failed');
  String get activitiesEmptyTitle => _text('activities.empty.title');
  String get activitiesEmptyMessage => _text('activities.empty.message');
  String get activitiesHistoryEmptyTitle =>
      _text('activities.history_empty.title');
  String get activitiesHistoryEmptyMessage =>
      _text('activities.history_empty.message');
  String get activityFallbackName => _text('activities.fallback_name');
  String activityTypeLabel(String type) {
    final key = switch (type) {
      'cashback' => 'activities.type.cashback',
      'lucky_board' => 'activities.type.lucky_board',
      _ => '',
    };
    if (key.isEmpty) return type.isEmpty ? activityFallbackName : type;
    return _text(key);
  }

  String activityPredictionLabel(String type) {
    final key = switch (type) {
      'first_prize_last2' => 'activities.prediction.first_prize_last2',
      'first_prize_last3' => 'activities.prediction.first_prize_last3',
      'last2' => 'activities.prediction.last2',
      _ => '',
    };
    if (key.isEmpty) return _text('activities.prediction.fallback');
    return _text(key);
  }

  String get activityConditionFallback =>
      _text('activities.condition.fallback');
  String activityConditionMinTickets(int count) {
    return _text('activities.condition.min_tickets').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String activityConditionMinBaht(String amount) {
    return _text('activities.condition.min_baht').replaceAll(
      '{amount}',
      amount,
    );
  }

  String activityMetaCashbackEstimate(String amount) {
    return _text('activities.meta.cashback_estimate').replaceAll(
      '{amount}',
      amount,
    );
  }

  String get activityMetaCashbackPending =>
      _text('activities.meta.cashback_pending');
  String get activityMetaEntryClosed => _text('activities.meta.entry_closed');
  String get activityMetaGuest => _text('activities.meta.guest');
  String get activityMetaPin => _text('activities.meta.pin');
  String get activityMetaRightsUsed => _text('activities.meta.rights_used');
  String get activityMetaNoRights => _text('activities.meta.no_rights');
  String activityMetaDeadline(String date) {
    return _text('activities.meta.deadline').replaceAll('{date}', date);
  }

  String get activityMetaDeadlineFallback =>
      _text('activities.meta.deadline_fallback');
  String activityMetaRights(int count) {
    return _text('activities.meta.rights').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String activityMetaRemainingNumbers(int count) {
    return _text('activities.meta.remaining_numbers').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get activityDetailTitle => _text('activity_detail.title');
  String get activityDetailLoading => _text('activity_detail.loading');
  String get activityDetailLoadFailed => _text('activity_detail.load_failed');
  String get activityDetailHasRight => _text('activity_detail.has_right');
  String get activityDetailEntryClosed => _text('activity_detail.entry_closed');
  String get activityDetailGameFallback =>
      _text('activity_detail.game_fallback');
  String activityDetailResultTime(String value) {
    return _text('activity_detail.result_time').replaceAll('{time}', value);
  }

  String get activityConfirmNumberEyebrow =>
      _text('activity_detail.confirm_number.eyebrow');
  String get activityConfirmNumberTitle =>
      _text('activity_detail.confirm_number.title');
  String activityConfirmNumberMessage(String number, String prediction) {
    return _text('activity_detail.confirm_number.message')
        .replaceAll('{number}', number)
        .replaceAll('{prediction}', prediction);
  }

  String get activityConfirmNumberSubmit =>
      _text('activity_detail.confirm_number.submit');
  String get activitySubmitEntrySuccess =>
      _text('activity_detail.entry.submit_success');
  String get activitySubmitEntryClosed => _text('activity_detail.entry.closed');
  String get activitySubmitEntryFailed =>
      _text('activity_detail.entry.submit_failed');
  String get activityStatusCashbackTitle =>
      _text('activity_detail.status.cashback_title');
  String get activityStatusNumberTitle =>
      _text('activity_detail.status.number_title');
  String get activityStatusCalculating =>
      _text('activity_detail.status.calculating');
  String activityStatusRemainingNumbers(int count) {
    return _text('activity_detail.status.remaining_numbers').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get activityStatusCashbackSubtitle =>
      _text('activity_detail.status.cashback_subtitle');
  String get activityStatusBoardClosed =>
      _text('activity_detail.status.board_closed');
  String get activityStatusBoardAvailable =>
      _text('activity_detail.status.board_available');
  String get activityCashbackPanelTitle =>
      _text('activity_detail.cashback.title');
  String get activityCashbackProgressEligible =>
      _text('activity_detail.cashback.progress_eligible');
  String get activityCashbackProgressPending =>
      _text('activity_detail.cashback.progress_pending');
  String get activityCashbackEligibleTitle =>
      _text('activity_detail.cashback.eligible_title');
  String get activityCashbackPendingTitle =>
      _text('activity_detail.cashback.pending_title');
  String activityCashbackEligibleDescription(String resultTime) {
    return _text(
      'activity_detail.cashback.eligible_description',
    ).replaceAll('{resultTime}', resultTime);
  }

  String activityCashbackPendingDescription(String minimum, String resultTime) {
    return _text('activity_detail.cashback.pending_description')
        .replaceAll('{minimum}', minimum)
        .replaceAll('{resultTime}', resultTime);
  }

  String get activityCashbackRewardFallback =>
      _text('activity_detail.cashback.reward_fallback');
  String get activityCashbackExpectedLabel =>
      _text('activity_detail.cashback.expected_label');
  String activityCashbackExpectedHint(String resultTime) {
    return _text(
      'activity_detail.cashback.expected_hint',
    ).replaceAll('{resultTime}', resultTime);
  }

  String get activityCashbackPurchaseAmount =>
      _text('activity_detail.cashback.purchase_amount');
  String get activityCashbackTicketCount =>
      _text('activity_detail.cashback.ticket_count');
  String get activityCashbackMinimum =>
      _text('activity_detail.cashback.minimum');
  String get activityCashbackNoMinimum =>
      _text('activity_detail.cashback.no_minimum');
  String activityCashbackTickets(int count) {
    return _text(
      'activity_detail.cashback.tickets',
    ).replaceAll('{count}', count.toString());
  }

  String get activityCashbackDetailRewardType =>
      _text('activity_detail.cashback.detail.reward_type');
  String get activityCashbackDetailMainCondition =>
      _text('activity_detail.cashback.detail.main_condition');
  String get activityCashbackDetailMainConditionValue =>
      _text('activity_detail.cashback.detail.main_condition_value');
  String get activityCashbackDetailCalculationTime =>
      _text('activity_detail.cashback.detail.calculation_time');
  String get activityCashbackDetailPayout =>
      _text('activity_detail.cashback.detail.payout');
  String get activityCashbackDetailPayoutValue =>
      _text('activity_detail.cashback.detail.payout_value');
  String get activityCashbackManualClaimTitle =>
      _text('activity_detail.cashback.manual_claim.title');
  String get activityCashbackManualClaimReady =>
      _text('activity_detail.cashback.manual_claim.ready');
  String get activityCashbackManualClaimPending =>
      _text('activity_detail.cashback.manual_claim.pending');
  String get activityCashbackAutoRewardTitle =>
      _text('activity_detail.cashback.auto_reward.title');
  String get activityCashbackAutoRewardSubtitle =>
      _text('activity_detail.cashback.auto_reward.subtitle');
  String get activityCashbackClaimNotReadyTitle =>
      _text('activity_detail.cashback.claim_not_ready.title');
  String get activityCashbackClaimNotReadyMessage =>
      _text('activity_detail.cashback.claim_not_ready.message');
  String get activityCashbackResultTimeFallback =>
      _text('activity_detail.cashback.result_time_fallback');
  String get activityResultTitle => _text('activity_detail.result.title');
  String activityResultWinningNumber(String prediction) {
    return _text('activity_detail.result.winning_number').replaceAll(
      '{prediction}',
      prediction,
    );
  }

  String activityResultCustomerWon(String amount) {
    return _text('activity_detail.result.customer_won').replaceAll(
      '{amount}',
      amount,
    );
  }

  String get activityResultCustomerLost =>
      _text('activity_detail.result.customer_lost');
  String get activityResultCustomerWinningNumbers =>
      _text('activity_detail.result.customer_winning_numbers');
  String activityResultWinnerCount(int count) {
    return _text('activity_detail.result.winner_count').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get activityAwardClaimButton =>
      _text('activity_detail.award.claim_button');
  String get activityAwardReady => _text('activity_detail.award.ready');
  String get activityAwardClaimed => _text('activity_detail.award.claimed');
  String get activityAwardProcessing =>
      _text('activity_detail.award.processing');
  String get activityAwardStatusTitle =>
      _text('activity_detail.award_status.title');
  String activityAwardStatusCount(int count) {
    return _text(
      'activity_detail.award_status.count',
    ).replaceAll('{count}', count.toString());
  }

  String get activityAwardStatusLoginCount =>
      _text('activity_detail.award_status.login_count');
  String get activityAwardStatusNotJoinedCount =>
      _text('activity_detail.award_status.not_joined_count');
  String get activityAwardStatusNoRewardCount =>
      _text('activity_detail.award_status.no_reward_count');
  String get activityAwardStatusPendingCount =>
      _text('activity_detail.award_status.pending_count');
  String get activityAwardStatusMissedTitle =>
      _text('activity_detail.award_status.missed_title');
  String get activityAwardStatusNotJoinedTitle =>
      _text('activity_detail.award_status.not_joined_title');
  String get activityAwardStatusPendingTitle =>
      _text('activity_detail.award_status.pending_title');
  String get activityAwardStatusLoginTitle =>
      _text('activity_detail.award_status.login_title');
  String get activityAwardStatusNoRewardTitle =>
      _text('activity_detail.award_status.no_reward_title');
  String get activityAwardStatusMissedMessage =>
      _text('activity_detail.award_status.missed_message');
  String get activityAwardStatusNotJoinedMessage =>
      _text('activity_detail.award_status.not_joined_message');
  String get activityAwardStatusPendingMessage =>
      _text('activity_detail.award_status.pending_message');
  String get activityAwardStatusLoginMessage =>
      _text('activity_detail.award_status.login_message');
  String get activityAwardStatusNoRewardMessage =>
      _text('activity_detail.award_status.no_reward_message');
  String get activityConditionTitle => _text('activity_detail.condition.title');
  String get activityRightsTitle => _text('activity_detail.rights.title');
  String get activityRightsEarned => _text('activity_detail.rights.earned');
  String get activityRightsUsed => _text('activity_detail.rights.used');
  String get activityRightsRemaining =>
      _text('activity_detail.rights.remaining');
  String activityRightsTicketSummary(int total, int consumed) {
    return _text('activity_detail.rights.ticket_summary')
        .replaceAll('{total}', total.toString())
        .replaceAll('{consumed}', consumed.toString());
  }

  String activityRightsDeadline(String date) {
    return _text('activity_detail.rights.deadline').replaceAll('{date}', date);
  }

  String get activitySelectedNumbersTitle =>
      _text('activity_detail.selected_numbers.title');
  String activityNumberBoardTitle(String prediction) {
    return _text('activity_detail.board.title').replaceAll(
      '{prediction}',
      prediction,
    );
  }

  String activityNumberBoardSummary(
    String range,
    String remaining,
    String total,
  ) {
    return _text('activity_detail.board.summary')
        .replaceAll('{range}', range)
        .replaceAll('{remaining}', remaining)
        .replaceAll('{total}', total);
  }

  String get activityNumberBoardCanSelect =>
      _text('activity_detail.board.can_select');
  String get activityNumberBoardClosed => _text('activity_detail.board.closed');
  String get activityNumberBoardNoRights =>
      _text('activity_detail.board.no_rights');
  String get activityNumberBoardReservedHint =>
      _text('activity_detail.board.reserved_hint');
  String get activityNumberBoardReservedShort =>
      _text('activity_detail.board.reserved_short');
  String get activityNumberBoardEntryClosedHint =>
      _text('activity_detail.board.entry_closed_hint');
  String get activityLoginToJoinTitle =>
      _text('activity_detail.login_to_join.title');
  String get activityLoginToJoinButton =>
      _text('activity_detail.login_to_join.button');
  String get activityClaimSheetTitle =>
      _text('activity_detail.claim_sheet.title');
  String get activityClaimSheetEyebrow =>
      _text('activity_detail.claim_sheet.eyebrow');
  String get activityClaimAvailableAmount =>
      _text('activity_detail.claim_sheet.available_amount');
  String get activityClaimWalletTitle =>
      _text('activity_detail.claim_sheet.wallet.title');
  String activityClaimWalletAccountTitle(String suffix) {
    return _text(
      'activity_detail.claim_sheet.wallet.account_title',
    ).replaceAll('{suffix}', suffix);
  }

  String activityClaimWalletSubtitle(String reviewerName) {
    return _text('activity_detail.claim_sheet.wallet.subtitle').replaceAll(
      '{reviewer}',
      reviewerName.trim().isEmpty
          ? profileAutoRewardReviewerFallback
          : reviewerName.trim(),
    );
  }

  String get activityClaimBankTitle =>
      _text('activity_detail.claim_sheet.bank.title');
  String get activityClaimBankReady =>
      _text('activity_detail.claim_sheet.bank.ready');
  String get activityClaimBankMissing =>
      _text('activity_detail.claim_sheet.bank.missing');
  String get activityClaimBankRecipientFallback =>
      _text('activity_detail.claim_sheet.bank.recipient_fallback');
  String get activityClaimSetupBank =>
      _text('activity_detail.claim_sheet.setup_bank');
  String get activityClaimConfirmPin =>
      _text('activity_detail.claim_sheet.confirm_pin');
  String get activityClaimPinTitle =>
      _text('activity_detail.claim_sheet.pin.title');
  String get activityClaimPinSubtitle =>
      _text('activity_detail.claim_sheet.pin.subtitle');
  String activityClaimPinProgress(int count) {
    return _text('activity_detail.claim_sheet.pin.progress').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get activityClaimProfileLoading =>
      _text('activity_detail.claim_sheet.profile_loading');
  String get activityClaimProfileLoadFailed =>
      _text('activity_detail.claim_sheet.profile_load_failed');
  String get activityClaimBankRequired =>
      _text('activity_detail.claim_sheet.bank_required');
  String get activityClaimPinInvalid =>
      _text('activity_detail.claim_sheet.pin_invalid');
  String get activityClaimPinLocked =>
      _text('activity_detail.claim_sheet.pin_locked');
  String get activityClaimPinSetupRequired =>
      _text('activity_detail.claim_sheet.pin_setup_required');
  String get activityClaimSubmitFailed =>
      _text('activity_detail.claim_sheet.submit_failed');
  String get activityClaimBiometricUnavailable =>
      _text('activity_detail.claim_sheet.biometric_unavailable');
  String get activityClaimBiometricFailed =>
      _text('activity_detail.claim_sheet.biometric_failed');
  String get activityClaimBiometricButton =>
      _text('activity_detail.claim_sheet.biometric_button');
  String get activityMissing => _text('activity_detail.missing');
  String get activityMissingTitle => _text('activity_detail.missing.title');
  String get activityMissingMessage => _text('activity_detail.missing.message');
  String get activityMissingBackToActivities =>
      _text('activity_detail.missing.back_to_activities');

  String get purchaseHistoryTitle => _text('purchase_history.title');
  String get purchaseHistoryHeaderTitle =>
      _text('purchase_history.header.title');
  String get purchaseHistoryHeaderSubtitle =>
      _text('purchase_history.header.subtitle');
  String get purchaseHistoryBuyTooltip => _text('purchase_history.buy_tooltip');
  String purchaseHistoryYear(String year) {
    return _text('purchase_history.year').replaceAll('{year}', year);
  }

  String get purchaseHistoryOrderTitle => _text('purchase_history.order_title');
  String get purchaseHistoryDigitalTicket =>
      _text('purchase_history.digital_ticket');
  String purchaseHistoryDrawDate(String date) {
    return _text('purchase_history.draw_date').replaceAll('{date}', date);
  }

  String purchaseHistoryTicketCount(int count) {
    return _text('purchase_history.ticket_count').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get purchaseHistoryLoadFailed => _text('purchase_history.load_failed');
  String get purchaseHistoryLoadMoreFailed =>
      _text('purchase_history.load_more_failed');
  String get purchaseHistoryEmptyTitle => _text('purchase_history.empty.title');
  String get purchaseHistoryEmptySubtitle =>
      _text('purchase_history.empty.subtitle');
  String get purchaseHistoryBuyButton => _text('purchase_history.buy_button');
  String get purchaseHistoryDetailTitle =>
      _text('purchase_history.detail.title');
  String get purchaseHistoryReceiptTitle =>
      _text('purchase_history.detail.receipt_title');
  String get purchaseHistoryReceiptSubtitle =>
      _text('purchase_history.detail.receipt_subtitle');
  String get purchaseHistoryTicketCountLabel =>
      _text('purchase_history.detail.ticket_count');
  String get purchaseHistoryDrawDateLabel =>
      _text('purchase_history.detail.draw_date');
  String get purchaseHistoryPayeeLabel =>
      _text('purchase_history.detail.payee');
  String get purchaseHistoryPaymentChannelLabel =>
      _text('purchase_history.detail.payment_channel');
  String get purchaseHistoryTotalLabel =>
      _text('purchase_history.detail.total');
  String purchaseHistoryTransactionAt(String date) {
    return _text('purchase_history.detail.transaction_at').replaceAll(
      '{date}',
      date,
    );
  }

  String purchaseHistoryReference(String reference) {
    return _text('purchase_history.detail.reference').replaceAll(
      '{reference}',
      reference,
    );
  }

  String get purchaseHistoryReferenceLabel =>
      _text('purchase_history.detail.reference_label');
  String get purchaseHistoryTicketListTitle =>
      _text('purchase_history.detail.ticket_list');
  String get purchaseHistoryDetailEmpty =>
      _text('purchase_history.detail.empty');
  String get purchaseHistoryStoreFallback =>
      _text('purchase_history.store_fallback');

  String get storesTitle => _text('stores.title');
  String get storesSearchLabel => _text('stores.search_label');
  String get storesRecommendedTitle => _text('stores.recommended.title');
  String get storesLoadFailedTitle => _text('stores.load_failed.title');
  String get storesLoadFailedMessage => _text('stores.load_failed.message');
  String get storesEmptyTitle => _text('stores.empty.title');
  String get storesEmptyMessage => _text('stores.empty.message');
  String get storesFallbackStoreName => _text('stores.fallback_store_name');
  String storeCode(String code) {
    return _text('stores.code').replaceAll('{code}', code);
  }

  String get storesLotteriesTitle => _text('stores.lotteries.title');
  String get storesLotteriesSubtitle => _text('stores.lotteries.subtitle');
  String get storesLotteriesLoadFailedTitle =>
      _text('stores.lotteries.load_failed.title');
  String get storesLotteriesLoadFailedMessage =>
      _text('stores.lotteries.load_failed.message');
  String get storesLotteriesEmptyTitle => _text('stores.lotteries.empty.title');
  String get storesLotteriesEmptyMessage =>
      _text('stores.lotteries.empty.message');
  String get storesTicketAvailable => _text('stores.ticket.available');
  String get storesTicketSoldOut => _text('stores.ticket.sold_out');
  String get affiliateTitle => _text('affiliate.title');
  String get affiliateBackTooltip => _text('affiliate.back_tooltip');
  String get affiliateRefreshTooltip => _text('affiliate.refresh_tooltip');
  String get affiliateLoadFailed => _text('affiliate.load_failed');
  String get affiliateStoreNameRequired =>
      _text('affiliate.register.store_name_required');
  String get affiliateRegisterSuccess => _text('affiliate.register.success');
  String get affiliateRegisterFailed => _text('affiliate.register.failed');
  String affiliateWithdrawMinimum(String amount) {
    return _text('affiliate.withdraw.minimum').replaceAll('{amount}', amount);
  }

  String get affiliateWithdrawExceeds => _text('affiliate.withdraw.exceeds');
  String get affiliateBankRequired => _text('affiliate.withdraw.bank_required');
  String get affiliatePayoutSuccess => _text('affiliate.withdraw.success');
  String get affiliatePayoutFailed => _text('affiliate.withdraw.failed');
  String get affiliateLinkCopied => _text('affiliate.link_copied');
  String get affiliatePinInvalid => _text('affiliate.pin.invalid');
  String get affiliatePinLocked => _text('affiliate.pin.locked');
  String get affiliatePinSetupRequired => _text('affiliate.pin.setup_required');
  String get affiliatePinFailed => _text('affiliate.pin.failed');
  String get affiliatePinTitle => _text('affiliate.pin.title');
  String get affiliatePinSubtitle => _text('affiliate.pin.subtitle');
  String get affiliateHeroFallbackTitle => _text('affiliate.hero.fallback');
  String get affiliateHeroSubtitle => _text('affiliate.hero.subtitle');
  String get affiliateStoreSummaryLabel =>
      _text('affiliate.store_summary.label');
  String get affiliateStoreSummaryDescription =>
      _text('affiliate.store_summary.description');
  String get affiliateRegisterTitle => _text('affiliate.register.title');
  String get affiliateRegisterDescription =>
      _text('affiliate.register.description');
  String get affiliateRegisterStoreLabel =>
      _text('affiliate.register.store_label');
  String get affiliateRegisterStoreHint =>
      _text('affiliate.register.store_hint');
  String get affiliateRegisterButton => _text('affiliate.register.button');
  String affiliateStatTitle(String id) => _text('affiliate.stats.$id.title');
  String affiliateStatSubtitle(String id) =>
      _text('affiliate.stats.$id.subtitle');
  String affiliateTabLabel(String id) => _text('affiliate.tab.$id');
  String get affiliateReferralTitle => _text('affiliate.referral.title');
  String get affiliateReferralDescription =>
      _text('affiliate.referral.description');
  String get affiliateReferralEmpty => _text('affiliate.referral.empty');
  String get affiliateReferralCopyTooltip =>
      _text('affiliate.referral.copy_tooltip');
  String get affiliateBankTitle => _text('affiliate.bank.title');
  String get affiliateBankDescription => _text('affiliate.bank.description');
  String get affiliateBankEmpty => _text('affiliate.bank.empty');
  String get affiliateEdit => _text('affiliate.edit');
  String get affiliateWithdrawTitle => _text('affiliate.withdraw.title');
  String get affiliateWithdrawDescription =>
      _text('affiliate.withdraw.description');
  String get affiliateWithdrawAmountLabel =>
      _text('affiliate.withdraw.amount_label');
  String get affiliateWithdrawMethodLabel =>
      _text('affiliate.withdraw.method_label');
  String get affiliateWithdrawBankTransfer =>
      _text('affiliate.withdraw.bank_transfer');
  String get affiliateWithdrawBankDescription =>
      _text('affiliate.withdraw.bank_description');
  String get affiliateWithdrawWalletCredit =>
      _text('affiliate.withdraw.wallet_credit');
  String get affiliateWithdrawBankMissing =>
      _text('affiliate.withdraw.bank_missing');
  String get affiliateWithdrawSubmit => _text('affiliate.withdraw.submit');
  String get affiliateCommissionsEmpty => _text('affiliate.commissions.empty');
  String get affiliatePayoutsEmpty => _text('affiliate.payouts.empty');
  String affiliatePayoutMethodLabel(String method) {
    final key = switch (method) {
      'wallet_credit' => 'affiliate.payout_method.wallet_credit',
      'bank_transfer' => 'affiliate.payout_method.bank_transfer',
      _ => '',
    };
    if (key.isEmpty) return method.isEmpty ? '-' : method;
    return _text(key);
  }

  String affiliateStatusLabel(String status) {
    final key = switch (status) {
      'active' => 'affiliate.status.active',
      'calculated' => 'affiliate.status.calculated',
      'approved' => 'affiliate.status.approved',
      'pending' => 'affiliate.status.pending',
      'paid' => 'affiliate.status.paid',
      'reversed' => 'affiliate.status.reversed',
      'rejected' => 'affiliate.status.rejected',
      _ => '',
    };
    if (key.isEmpty) return status.isEmpty ? '-' : status;
    return _text(key);
  }

  String get ticketsTitle => _text('tickets.title');
  String get ticketsLoading => _text('tickets.loading');
  String get ticketsLoadFailed => _text('tickets.load_failed');
  String get ticketsHistoryTooltip => _text('tickets.history_tooltip');
  String get ticketsCurrentDrawTitle => _text('tickets.current_draw.title');
  String get ticketsCurrentDrawSubtitle =>
      _text('tickets.current_draw.subtitle');
  String get ticketsSearchNumbers => _text('tickets.search_numbers');
  String get ticketsSearchPlaceholder => _text('tickets.search.placeholder');
  String get ticketsSearchSubmit => _text('tickets.search.submit');
  String get ticketsSearchClear => _text('tickets.search.clear');
  String ticketsSearchResult(String query) {
    return _text('tickets.search.result').replaceAll('{query}', query);
  }

  String get ticketsSearchEmptyTitle => _text('tickets.search.empty.title');
  String get ticketsSearchEmptySubtitle =>
      _text('tickets.search.empty.subtitle');
  String get ticketsDrawDateLabel => _text('tickets.draw_date_label');
  String ticketsTotalCount(int count) {
    return _text('tickets.total_count').replaceAll('{count}', count.toString());
  }

  String get ticketsWinningBannerTitle => _text('tickets.winning_banner.title');
  String ticketsWinningBannerMessage(int count) {
    return _text('tickets.winning_banner.message').replaceAll(
      '{count}',
      count.toString(),
    );
  }

  String get ticketsTabCurrent => _text('tickets.tab.current');
  String get ticketsTabHistory => _text('tickets.tab.history');
  String get ticketsEmptyTitle => _text('tickets.empty.title');
  String get ticketsEmptySubtitle => _text('tickets.empty.subtitle');
  String get ticketsFooterNote => _text('tickets.footer_note');
  String get ticketsNumberFallback => _text('tickets.number_fallback');
  String get ticketStubDigitalLabel => _text('tickets.stub.digital_label');
  String get ticketStubSeriesLabel => _text('tickets.stub.series_label');
  String get ticketStubPriceLabel => _text('tickets.stub.price_label');
  String get ticketStubClaimStart => _text('tickets.stub.claim_start');
  String ticketStubPrizeAmount(String amount) {
    return _text('tickets.stub.prize_amount').replaceAll('{amount}', amount);
  }

  String ticketsCount(int count) {
    return _text('tickets.count').replaceAll('{count}', count.toString());
  }

  String get ticketStatusWinning => _text('tickets.status.winning');
  String get ticketStatusNonWinning => _text('tickets.status.non_winning');
  String get ticketStatusClaimFailed => _text('tickets.status.claim_failed');
  String get ticketStatusClaimCancelled =>
      _text('tickets.status.claim_cancelled');
  String get ticketStatusApproved => _text('tickets.status.approved');
  String get ticketStatusPaid => _text('tickets.status.paid');
  String get ticketStatusPendingClaim => _text('tickets.status.pending_claim');
  String get ticketStatusPendingResult =>
      _text('tickets.status.pending_result');
  String get ticketPrizeFallback => _text('tickets.prize.fallback');
  String ticketPrizeMore(String prizeName, int count) {
    return _text('tickets.prize.more')
        .replaceAll('{prize}', prizeName)
        .replaceAll('{count}', count.toString());
  }

  String ticketPrizeType(String type) {
    final key = switch (type) {
      'first_prize' => 'tickets.prize.first_prize',
      'near_first_prize' => 'tickets.prize.near_first_prize',
      'second_prize' => 'tickets.prize.second_prize',
      'third_prize' => 'tickets.prize.third_prize',
      'fourth_prize' => 'tickets.prize.fourth_prize',
      'fifth_prize' => 'tickets.prize.fifth_prize',
      'front3' => 'tickets.prize.front3',
      'back3' => 'tickets.prize.back3',
      'back2' => 'tickets.prize.back2',
      _ => 'tickets.prize.fallback',
    };
    return _text(key);
  }

  String get ticketHistoryTitle => _text('tickets.history.title');
  String get ticketCurrentTooltip => _text('tickets.current_tooltip');
  String get ticketHistoryHeaderTitle => _text('tickets.history.header.title');
  String get ticketHistoryHeaderSubtitle =>
      _text('tickets.history.header.subtitle');
  String get ticketHistoryListTitle => _text('tickets.history.list_title');
  String get ticketHistoryShowWinning => _text('tickets.history.show_winning');
  String get ticketHistoryShowAll => _text('tickets.history.show_all');
  String get ticketHistoryNoWinningSummary =>
      _text('tickets.history.no_winning_summary');
  String get ticketHistoryPastTicketsLabel =>
      _text('tickets.history.past_tickets_label');
  String get ticketHistoryCompletedDrawFallback =>
      _text('tickets.history.completed_draw_fallback');
  String ticketHistoryAllDraws(int count) {
    return _text(
      'tickets.history.all_draws',
    ).replaceAll('{count}', count.toString());
  }

  String ticketHistoryItemCount(int count) {
    return _text(
      'tickets.history.item_count',
    ).replaceAll('{count}', count.toString());
  }

  String get ticketHistoryLoadFailed => _text('tickets.history.load_failed');
  String get ticketHistoryLoadMoreFailed =>
      _text('tickets.history.load_more_failed');
  String get ticketHistoryEmptyTitle => _text('tickets.history.empty.title');
  String get ticketHistoryEmptySubtitle =>
      _text('tickets.history.empty.subtitle');
  String get ticketHistoryWinningEmptyTitle =>
      _text('tickets.history.winning_empty.title');
  String get ticketHistoryWinningEmptySubtitle =>
      _text('tickets.history.winning_empty.subtitle');
  String get commonLoadingMore => _text('common.loading_more');
  String get commonLoadMore => _text('common.load_more');
  String get commonAllLoaded => _text('common.all_loaded');
  String get ticketDetailTitle => _text('tickets.detail.title');
  String get commonBack => _text('common.back');
  String get ticketsNotFound => _text('tickets.not_found');
  String get ticketLabelLotteryNumber => _text('tickets.label.lottery_number');
  String get ticketLabelDraw => _text('tickets.label.draw');
  String get ticketLabelDrawDate => _text('tickets.label.draw_date');
  String get ticketLabelLotteryDrawDate =>
      _text('tickets.label.lottery_draw_date');
  String get ticketLabelDrawNumber => _text('tickets.label.draw_number');
  String get ticketLabelSetNumber => _text('tickets.label.set_number');
  String get ticketLabelCount => _text('tickets.label.count');
  String get ticketLabelPrizeAmount => _text('tickets.label.prize_amount');
  String get ticketLabelRecipient => _text('tickets.label.recipient');
  String get ticketLabelPayoutChannel => _text('tickets.label.payout_channel');
  String get ticketLabelNetAmount => _text('tickets.label.net_amount');
  String get ticketLabelSubmittedAt => _text('tickets.label.submitted_at');
  String get ticketLabelPrize => _text('tickets.label.prize');
  String get ticketLabelGovernmentLottery =>
      _text('tickets.label.government_lottery');
  String get ticketClaimViewClaim => _text('tickets.claim.view_claim');
  String get ticketClaimViewReward => _text('tickets.claim.view_reward');
  String get ticketClaimStart => _text('tickets.claim.start');
  String get ticketClaimPinTitle => _text('tickets.claim.pin_title');
  String get ticketClaimTitle => _text('tickets.claim.title');
  String get ticketClaimConfirmTitle => _text('tickets.claim.confirm_title');
  String get ticketClaimAlreadyTitle =>
      _text('tickets.claim.already_claimed.title');
  String get ticketClaimAlreadySubtitle =>
      _text('tickets.claim.already_claimed.subtitle');
  String get ticketClaimLoading => _text('tickets.claim.loading');
  String get ticketClaimLoadFailed => _text('tickets.claim.load_failed');
  String get ticketClaimSubmitFailed => _text('tickets.claim.submit_failed');
  String get ticketClaimBiometricUnavailable =>
      _text('tickets.claim.biometric_unavailable');
  String get ticketClaimBiometricFailed =>
      _text('tickets.claim.biometric_failed');
  String get ticketClaimPinInvalid => _text('tickets.claim.pin_invalid');
  String get ticketClaimPinLocked => _text('tickets.claim.pin_locked');
  String get ticketClaimPinSetupRequired =>
      _text('tickets.claim.pin_setup_required');
  String get ticketClaimPinAssertionInvalid =>
      _text('tickets.claim.pin_assertion_invalid');
  String get ticketClaimConflict => _text('tickets.claim.conflict');
  String get ticketClaimPayoutMethodTitle =>
      _text('tickets.claim.payout_method_title');
  String get ticketClaimWalletTitle => _text('tickets.claim.wallet.title');
  String ticketClaimWalletAccountTitle(String suffix) {
    return _text(
      'tickets.claim.wallet.account_title',
    ).replaceAll('{suffix}', suffix);
  }

  String get ticketClaimWalletSubtitle =>
      _text('tickets.claim.wallet.subtitle');
  String get ticketClaimBankTitle => _text('tickets.claim.bank.title');
  String get ticketClaimBankSubtitleReady =>
      _text('tickets.claim.bank.subtitle_ready');
  String get ticketClaimBankSubtitleMissing =>
      _text('tickets.claim.bank.subtitle_missing');
  String get ticketClaimBankAccountNumberLabel =>
      _text('tickets.claim.bank.account_number');
  String get ticketClaimAddBank => _text('tickets.claim.add_bank');
  String get ticketClaimUnavailablePendingResult =>
      _text('tickets.claim.unavailable.pending_result');
  String get ticketClaimUnavailableNonWinning =>
      _text('tickets.claim.unavailable.non_winning');
  String get ticketClaimUnavailableWinningNotOpen =>
      _text('tickets.claim.unavailable.winning_not_open');
  String get ticketClaimUnavailableDefault =>
      _text('tickets.claim.unavailable.default');
  String get ticketClaimEnterPin => _text('tickets.claim.enter_pin');
  String get ticketClaimProcessingTitle =>
      _text('tickets.claim.processing.title');
  String get ticketClaimProcessingSubtitle =>
      _text('tickets.claim.processing.subtitle');
  String get ticketClaimViewMyTickets => _text('tickets.claim.view_my_tickets');
  String get ticketImageUnavailable => _text('tickets.image.unavailable');
  String get ticketImagePreparing => _text('tickets.image.preparing');
  String get ticketImageOpenPreview => _text('tickets.image.open_preview');
  String get ticketImageClosePreview => _text('tickets.image.close_preview');
  String ticketImageAlt(String number) {
    return _text('tickets.image.alt').replaceAll('{number}', number);
  }

  String get ticketImageGovernmentLotteryEnglish =>
      _text('tickets.image.government_lottery_english');
  String get ticketImageDigitalWatermark =>
      _text('tickets.image.digital_watermark');
  String get ticketImageDigitalNumberLabel =>
      _text('tickets.image.digital_number_label');
  String get ticketImageCurrentDraw => _text('tickets.image.current_draw');
  String get ticketImageDigitalType => _text('tickets.image.digital_type');
  String get ticketImageSold => _text('tickets.image.sold');
  String get ticketImageTenantFallback =>
      _text('tickets.image.tenant_fallback');
  String ticketImageModalNote(String siteName, String productName) {
    return _text('tickets.image.modal_note')
        .replaceAll('{site}', siteName)
        .replaceAll('{product}', productName);
  }

  String _text(String key) {
    final tag = localeTag(locale);
    return runtimeValues[key] ??
        _localizedValues[tag]?[key] ??
        _localizedValues['th-TH']?[key] ??
        key;
  }

  String formatBaht(num value) {
    return formatBahtForLocale(
      value,
      localeTag: localeTag(locale),
      unit: commonBahtSuffix,
    );
  }

  String formatSignedBaht(num value) {
    return formatSignedBahtForLocale(
      value,
      localeTag: localeTag(locale),
      unit: commonBahtSuffix,
    );
  }
}

extension CustomerLocalizationsX on BuildContext {
  CustomerLocalizations get l10n => CustomerLocalizations.of(this);
}

class _CustomerLocalizationsDelegate
    extends LocalizationsDelegate<CustomerLocalizations> {
  const _CustomerLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return supportedCustomerLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<CustomerLocalizations> load(Locale locale) async {
    return CustomerLocalizations(parseCustomerLocale(localeTag(locale)));
  }

  @override
  bool shouldReload(_CustomerLocalizationsDelegate old) => false;
}

class RuntimeCustomerLocalizationsDelegate
    extends LocalizationsDelegate<CustomerLocalizations> {
  const RuntimeCustomerLocalizationsDelegate(this.runtimeValues);

  final Map<String, String> runtimeValues;

  @override
  bool isSupported(Locale locale) {
    return supportedCustomerLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<CustomerLocalizations> load(Locale locale) async {
    return CustomerLocalizations(
      parseCustomerLocale(localeTag(locale)),
      runtimeValues: runtimeValues,
    );
  }

  @override
  bool shouldReload(RuntimeCustomerLocalizationsDelegate old) {
    return old.runtimeValues != runtimeValues;
  }
}

const _localizedValues = <String, Map<String, String>>{
  'th-TH': {
    'bottom_nav.home': 'หน้าหลัก',
    'bottom_nav.tickets': 'สลากฯ ของฉัน',
    'bottom_nav.wallet': 'กระเป๋าเงิน',
    'bottom_nav.more': 'อื่นๆ',
    'common.language': 'ภาษา',
    'common.thai': 'ไทย',
    'common.english': 'English',
    'common.money.baht_suffix': 'บาท',
    'app_alert.default_title': 'แจ้งเตือน',
    'app_alert.default_button': 'รับทราบ',
    'app_splash.preparing': 'กำลังเตรียมข้อมูลระบบ',
    'sale_closure.alert_message':
        'ระบบพาไปหน้ารอออกผลแล้ว กรุณาตรวจผลรางวัลหลังประกาศผล',
    'routes.home.title': 'หน้าหลัก',
    'routes.home.description':
        'ค้นหาเลขเด็ด กระเป๋าเงิน กิจกรรม ข่าวสาร และผลรางวัลล่าสุด',
    'routes.buy.title': 'ซื้อสลาก',
    'routes.buy.description': 'ค้นหา เลือก และจองสลากดิจิทัล',
    'routes.buy_search.title': 'ค้นหาเลขสลาก',
    'routes.buy_search.description': 'ค้นหาเลข 6 หลัก พร้อมจำสถานะการค้นหาเดิม',
    'routes.search.title': 'ค้นหาเลขสลาก',
    'routes.buy_more.title': 'ดูเลขนี้เพิ่มเติม',
    'routes.buy_more.description': 'แสดงสลากหมายเลขใกล้เคียงจากผลค้นหาเดิม',
    'routes.cart.title': 'ตะกร้าสลาก',
    'routes.checkout.title': 'ชำระเงิน',
    'routes.checkout_pending.title': 'รอชำระเงิน',
    'routes.tickets.title': 'สลากฯ ของฉัน',
    'routes.tickets.description': 'สลากปัจจุบัน สลากย้อนหลัง และสถานะขึ้นเงิน',
    'routes.tickets_history.title': 'ประวัติสลาก',
    'routes.tickets_view.title': 'ดูรูปสลาก',
    'routes.ticket_claim.title': 'ขึ้นเงินจากสลาก',
    'routes.result.title': 'ผลรางวัล',
    'routes.result.description':
        'ผลสดอย่างไม่เป็นทางการและผลรางวัลที่เผยแพร่แล้ว',
    'routes.result_full.title': 'ผลรางวัลแบบเต็ม',
    'routes.results.title': 'ผลรางวัล',
    'routes.results_full.title': 'ผลรางวัลแบบเต็ม',
    'routes.waiting_result.title': 'รอออกผล',
    'routes.my_wallet.title': 'กระเป๋าของฉัน',
    'routes.my_wallet.description':
        'ยอดเงิน ปุ่มเติมเงิน และรายการเดินเงินล่าสุด',
    'routes.topup.title': 'เติมเงินเข้า G-Wallet',
    'routes.topup_history.title': 'ประวัติเติมเงิน',
    'routes.reward_claims.title': 'ขึ้นเงินรางวัล',
    'routes.reward_claim_detail.title': 'รายละเอียดขึ้นเงินรางวัล',
    'routes.activity_claims.title': 'ประวัติขึ้นเงินรางวัลกิจกรรม',
    'routes.activity_claim_detail.title': 'รายละเอียดขึ้นเงินรางวัลกิจกรรม',
    'routes.activities.title': 'กิจกรรม',
    'routes.activities.description': 'กิจกรรมประจำงวดและกิจกรรมงวดย้อนหลัง',
    'routes.activities_history.title': 'กิจกรรมงวดย้อนหลัง',
    'routes.activity_detail.title': 'รายละเอียดกิจกรรม',
    'routes.affiliate.title': 'Affiliate',
    'routes.profile.title': 'โปรไฟล์',
    'routes.profile_auto_reward.title': 'ขึ้นเงินรางวัลอัตโนมัติ',
    'routes.profile_line_notifications.title': 'แจ้งเตือนผ่าน LINE',
    'routes.profile_reward_bank.title': 'บัญชีรับเงินรางวัล',
    'routes.profile_biometrics.title': 'อุปกรณ์ Biometric',
    'routes.profile_account_deletion.title': 'ลบบัญชีผู้ใช้',
    'routes.purchase_history.title': 'ประวัติการซื้อสลาก',
    'routes.purchase_history_detail.title': 'รายละเอียดการซื้อสลาก',
    'routes.stores.title': 'ร้านค้า',
    'routes.store_lotteries.title': 'ร้านสลากหกหลักแบบดิจิทัล',
    'routes.news.title': 'ข่าวสาร',
    'routes.news_detail.title': 'รายละเอียดข่าวสาร',
    'routes.terms.title': 'ข้อตกลงและเงื่อนไข',
    'routes.privacy.title': 'นโยบายความเป็นส่วนตัว',
    'routes.term_reward.title': 'เงื่อนไขเงินรางวัล',
    'routes.lottery_knowledge.title': 'ข้อควรรู้การซื้อ-ขายสลากฯ',
    'routes.login.title': 'เข้าสู่ระบบ',
    'routes.register.title': 'สมัครสมาชิก',
    'routes.forgot_password.title': 'ลืมรหัสผ่าน',
    'routes.reset_password.title': 'ตั้งรหัสผ่านใหม่',
    'routes.line_callback.title': 'LINE Callback',
    'routes.line_link_phone.title': 'ผูกบัญชีด้วย LINE',
    'routes.social_callback.title': 'Social Login Callback',
    'routes.social_link_phone.title': 'ผูกบัญชีโซเชียล',
    'routes.pin.title': 'ยืนยัน PIN',
    'routes.security_lock.title': 'ล็อกหน้าจอความปลอดภัย',
    'routes.maintenance.title': 'ปิดปรับปรุง',
    'routes.account_suspended.title': 'บัญชีถูกระงับ',
    'routes.countdown.title': 'รอเปิดขาย',
    'routes.success.title': 'ทำรายการสำเร็จ',
    'routes.badge.sensitive': 'ข้อมูลสำคัญ',
    'routes.badge.public': 'สาธารณะ',
    'routes.group.storefront': 'หน้าร้าน',
    'routes.group.lottery': 'สลาก',
    'routes.group.wallet': 'กระเป๋าเงิน',
    'routes.group.account': 'บัญชี',
    'routes.group.content': 'เนื้อหา',
    'routes.group.system': 'ระบบ',
    'auth.login.title': 'เข้าสู่ระบบ',
    'auth.login.hero_badge': 'สลากดิจิทัล',
    'auth.login.hero_description':
        'ซื้อ ตรวจสอบ และจัดการสลากฯ ของคุณได้ในที่เดียว',
    'auth.login.form_title': 'ยืนยันตัวตน',
    'auth.login.form_description': 'ใช้เบอร์โทรศัพท์ที่ผูกกับบัญชีของคุณ',
    'auth.login.identifier_label': 'เบอร์โทรศัพท์หรืออีเมล',
    'auth.login.identifier_hint': 'กรอกเบอร์โทรศัพท์',
    'auth.login.password_label': 'รหัสผ่าน',
    'auth.login.password_hint': 'กรอกรหัสผ่าน',
    'auth.login.submit': 'เข้าสู่ระบบ',
    'auth.login.submitting': 'กำลังเข้าสู่ระบบ',
    'auth.login.register': 'สมัครใช้งาน',
    'auth.login.register_prompt': 'ยังไม่มีบัญชี?',
    'auth.login.forgot_password': 'ลืมรหัสผ่าน?',
    'auth.login.remember_me': 'จดจำการเข้าสู่ระบบ',
    'auth.login.divider': 'หรือ',
    'auth.login.show_password': 'แสดงรหัสผ่าน',
    'auth.login.hide_password': 'ซ่อนรหัสผ่าน',
    'auth.login.social_continue': 'เข้าสู่ระบบด้วย {provider}',
    'auth.login.social_opening': 'กำลังเชื่อมต่อ {provider}',
    'auth.login.failed': 'เข้าสู่ระบบไม่สำเร็จ',
    'auth.login.social_link_missing': 'ไม่พบลิงก์เข้าสู่ระบบ',
    'auth.login.social_failed': 'เข้าสู่ระบบด้วยผู้ให้บริการไม่สำเร็จ',
    'auth.validation.required': 'กรุณากรอกข้อมูล',
    'auth.validation.phone_invalid': 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง',
    'auth.validation.otp_invalid': 'กรุณากรอก OTP 6 หลัก',
    'auth.validation.confirm_password_required': 'กรุณายืนยันรหัสผ่าน',
    'auth.validation.password_mismatch': 'รหัสผ่านไม่ตรงกัน',
    'auth.otp.sent_to': 'ส่งรหัสไปยัง {phone}',
    'auth.otp.resend_in': 'ส่งใหม่ได้ใน {seconds} วินาที',
    'auth.otp.resend': 'ส่งรหัสใหม่',
    'auth.otp.label': 'รหัส OTP 6 หลัก',
    'auth.otp.verification_failed':
        'ยืนยัน OTP ไม่สำเร็จ กรุณาขอรหัสใหม่อีกครั้ง',
    'auth.register.title': 'สมัครใช้งาน',
    'auth.register.hero_badge': 'บัญชีเป๋าตัง',
    'auth.register.hero_description':
        'สร้างบัญชีเพื่อซื้อ ตรวจสลากฯ และเก็บรายการของคุณอย่างปลอดภัย',
    'auth.register.form_title': 'ข้อมูลบัญชี',
    'auth.register.form_description':
        'กรอกข้อมูลให้ตรงกับเบอร์โทรศัพท์ที่ใช้งาน',
    'auth.register.header_title': 'สร้างบัญชีลูกค้า',
    'auth.register.header_subtitle':
        'ยืนยันเบอร์โทรศัพท์ด้วย OTP ก่อนเริ่มใช้งาน',
    'auth.register.first_name': 'ชื่อ',
    'auth.register.first_name_hint': 'กรอกชื่อ',
    'auth.register.last_name': 'สกุล',
    'auth.register.last_name_hint': 'กรอกสกุล',
    'auth.register.phone': 'เบอร์โทรศัพท์',
    'auth.register.phone_hint': 'กรอกเบอร์โทรศัพท์',
    'auth.register.password': 'รหัสผ่าน',
    'auth.register.password_hint': 'ตั้งรหัสผ่าน',
    'auth.register.confirm_password': 'ยืนยันรหัสผ่าน',
    'auth.register.confirm_password_hint': 'กรอกรหัสผ่านอีกครั้ง',
    'auth.register.show_password': 'แสดงรหัสผ่าน',
    'auth.register.hide_password': 'ซ่อนรหัสผ่าน',
    'auth.register.terms': 'ยอมรับข้อตกลงและเงื่อนไขการใช้งาน',
    'auth.register.otp_title': 'ยืนยัน OTP',
    'auth.register.otp_hint': 'กรอกรหัส OTP',
    'auth.register.submit': 'สมัครใช้งาน',
    'auth.register.submit_with_otp': 'ยืนยันและสมัครใช้งาน',
    'auth.register.submitting': 'กำลังสมัครใช้งาน',
    'auth.register.login_link': 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
    'auth.register.login_prompt': 'มีบัญชีอยู่แล้ว?',
    'auth.register.terms_required':
        'กรุณายอมรับข้อตกลงและเงื่อนไขก่อนสมัครใช้งาน',
    'auth.register.failed':
        'สมัครใช้งานไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่',
    'auth.forgot.title': 'ลืมรหัสผ่าน',
    'auth.forgot.hero_title': 'ขอรีเซ็ตรหัสผ่าน',
    'auth.forgot.hero_description':
        'ยืนยันตัวตนด้วย OTP แล้วตั้งรหัสผ่านใหม่ได้ทันที',
    'auth.forgot.title_phone': 'รีเซ็ตรหัสผ่านด้วย OTP',
    'auth.forgot.title_otp': 'ยืนยันรหัส OTP',
    'auth.forgot.title_password': 'ตั้งรหัสผ่านใหม่',
    'auth.forgot.title_done': 'เปลี่ยนรหัสผ่านแล้ว',
    'auth.forgot.description_phone':
        'กรอกเบอร์โทรศัพท์ที่ใช้สมัครเพื่อรับรหัส OTP',
    'auth.forgot.description_otp': 'กรอกรหัส 6 หลักที่ส่งไปยังเบอร์ของคุณ',
    'auth.forgot.description_otp_sent_to': 'กรอกรหัส 6 หลักที่ส่งไปยัง {phone}',
    'auth.forgot.description_password': 'ตั้งรหัสผ่านใหม่สำหรับบัญชีนี้',
    'auth.forgot.description_done':
        'คุณสามารถเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้ทันที',
    'auth.forgot.button_send_otp': 'ส่งรหัส OTP',
    'auth.forgot.button_verify_otp': 'ยืนยัน OTP',
    'auth.forgot.button_save_password': 'บันทึกรหัสผ่านใหม่',
    'auth.forgot.back_to_login': 'กลับไปเข้าสู่ระบบ',
    'auth.forgot.new_password': 'รหัสผ่านใหม่',
    'auth.forgot.confirm_new_password': 'ยืนยันรหัสผ่านใหม่',
    'auth.forgot.phone_hint': 'กรอกเบอร์โทรศัพท์',
    'auth.forgot.otp_hint': 'กรอกรหัส OTP',
    'auth.forgot.password_hint': 'ตั้งรหัสผ่านใหม่',
    'auth.forgot.confirm_password_hint': 'กรอกรหัสผ่านอีกครั้ง',
    'auth.forgot.submitting': 'กำลังดำเนินการ',
    'auth.forgot.failed': 'ดำเนินการไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่',
    'auth.forgot.otp_provider_unavailable':
        'ร้านค้ายังไม่ได้เปิดบริการ OTP สำหรับรีเซ็ตรหัสผ่าน กรุณาใช้ LINE หรือช่องทางติดต่อร้านค้า',
    'auth.forgot.done_message': 'บันทึกรหัสผ่านใหม่เรียบร้อยแล้ว',
    'auth.forgot.line_title': 'รีเซ็ตด้วย LINE',
    'auth.forgot.line_description':
        'ถ้าคุณเคยเชื่อมต่อ LINE กับบัญชีนี้ไว้ สามารถยืนยันผ่าน LINE แล้วตั้งรหัสใหม่ได้เลย',
    'auth.forgot.line_button': 'รีเซ็ตด้วย LINE',
    'auth.forgot.line_opening': 'กำลังเปิด LINE',
    'auth.forgot.line_failed':
        'รีเซ็ตด้วย LINE ไม่สำเร็จ บัญชีนี้อาจยังไม่ได้เชื่อมต่อ LINE หรือร้านค้ายังไม่ได้ตั้งค่า LINE',
    'auth.reset.title': 'ตั้งรหัสผ่านใหม่',
    'auth.reset.header': 'รหัสผ่านใหม่',
    'auth.reset.line_description':
        'ยืนยันผ่าน LINE สำเร็จแล้ว ตั้งรหัสผ่านใหม่เพื่อใช้งานต่อ',
    'auth.reset.link_description':
        'ใช้ลิงก์ที่ได้รับจากผู้ดูแลร้านค้าเพื่อตั้งรหัสผ่านใหม่',
    'auth.reset.card_description': 'กรอกรหัสผ่านใหม่และยืนยันให้ตรงกัน',
    'auth.reset.invalid_title': 'ลิงก์ไม่ถูกต้อง',
    'auth.reset.invalid_message': 'กรุณาขอลิงก์รีเซ็ตรหัสผ่านใหม่อีกครั้ง',
    'auth.reset.new_password': 'รหัสผ่านใหม่',
    'auth.reset.new_password_hint': 'กรอกรหัสผ่านใหม่',
    'auth.reset.confirm_new_password': 'ยืนยันรหัสผ่านใหม่',
    'auth.reset.confirm_new_password_hint': 'กรอกอีกครั้ง',
    'auth.reset.show_password': 'แสดงรหัสผ่าน',
    'auth.reset.hide_password': 'ซ่อนรหัสผ่าน',
    'auth.reset.save': 'บันทึกรหัสผ่านใหม่',
    'auth.reset.submitting': 'กำลังบันทึก',
    'auth.reset.password_required': 'กรุณากรอกรหัสผ่านใหม่',
    'auth.reset.success': 'ตั้งรหัสผ่านใหม่แล้ว กรุณาเข้าสู่ระบบอีกครั้ง',
    'auth.reset.expired': 'ลิงก์อาจหมดอายุ กรุณาขอลิงก์ใหม่อีกครั้ง',
    'auth.social.callback.waiting':
        'กรุณารอสักครู่ ระบบกำลังยืนยันข้อมูลจาก {provider}',
    'auth.social.callback.title': 'กำลังเข้าสู่ระบบ',
    'auth.social.callback.missing_code':
        'ไม่พบข้อมูลยืนยันจาก {provider} กรุณาลองเชื่อมต่อใหม่อีกครั้ง',
    'auth.social.callback.failed': 'ไม่สามารถเข้าสู่ระบบด้วย {provider} ได้',
    'auth.social.callback.connect_failed':
        'ไม่สามารถเชื่อมต่อเพื่อเข้าสู่ระบบด้วย {provider} ได้',
    'auth.social.link.title': 'ผูกบัญชีด้วย {provider}',
    'auth.social.link.phone_title': 'ยืนยันเบอร์โทรศัพท์',
    'auth.social.link.phone_subtitle':
        'หากเบอร์นี้มีบัญชีอยู่แล้ว ระบบจะตรวจรหัสผ่านเดิมและผูกบัญชีโซเชียลเข้ากับบัญชีนั้นทันที',
    'auth.social.link.hero_subtitle':
        'ยืนยันเบอร์โทรศัพท์เพื่อใช้งานบัญชีเดิม หรือสร้างบัญชีใหม่ด้วย {provider}',
    'auth.social.link.password_hint': 'รหัสผ่านบัญชีเดิม หรือรหัสผ่านใหม่',
    'auth.social.link.confirm_password_hint': 'กรอกซ้ำเพื่อสร้างบัญชีใหม่',
    'auth.social.link.submit': 'ยืนยันและเข้าสู่ระบบ',
    'auth.social.link.submitting': 'กำลังยืนยัน',
    'auth.social.link.missing':
        'ไม่พบข้อมูลเชื่อมต่อ {provider} กรุณาเริ่มใหม่อีกครั้ง',
    'auth.social.link.failed': 'ผูกบัญชี {provider} ไม่สำเร็จ',
    'auth.social.profile.account': 'บัญชี {provider}',
    'auth.social.profile.fallback_name': 'ลูกค้า {provider}',
    'auth.social.profile.ready': 'พร้อมผูกบัญชีและเข้าสู่ระบบ',
    'auth.social.profile.status': 'พร้อมผูกบัญชี',
    'pin.title': 'ใส่รหัส PIN 6 หลัก',
    'pin.description': 'เพื่อทำรายการต่อ',
    'pin.setup.title': 'ตั้งรหัส PIN 6 หลัก',
    'pin.setup.confirm_title': 'ยืนยันรหัส PIN 6 หลัก',
    'pin.setup.description': 'เพื่อใช้เข้าใช้งานต่อ',
    'pin.setup.confirm_description': 'กรอกรหัสเดิมอีกครั้ง',
    'pin.setup.confirm_helper': 'ยืนยัน PIN ที่ตั้งไว้',
    'pin.setup.submitting': 'กำลังตั้งรหัสเข้าใช้งาน',
    'pin.verifying': 'กำลังตรวจสอบ',
    'pin.setup.mismatch': 'PIN ไม่ตรงกัน กรุณาตั้งใหม่อีกครั้ง',
    'pin.setup.failed': 'ไม่สามารถตั้ง PIN ได้ กรุณาลองใหม่อีกครั้ง',
    'pin.use_biometric': 'ใช้ Face ID / Biometric',
    'pin.biometric_reason': 'ยืนยันตัวตนเพื่อปลดล็อกและดำเนินการต่อ',
    'pin.biometric_unavailable': 'ยังไม่สามารถใช้ biometric ได้ กรุณาใช้ PIN',
    'pin.biometric_failed': 'ยืนยันด้วย biometric ไม่สำเร็จ กรุณาใช้ PIN',
    'pin.forgot': 'ลืม PIN?',
    'pin.invalid': 'PIN ไม่ถูกต้อง กรุณาลองใหม่',
    'pin.reset.title_request': 'ลืม PIN',
    'pin.reset.title_otp': 'ยืนยัน OTP',
    'pin.reset.title_pin': 'ตั้ง PIN ใหม่',
    'pin.reset.title_done': 'ตั้ง PIN ใหม่แล้ว',
    'pin.reset.description_request': 'ยืนยันด้วย OTP ก่อนตั้ง PIN ใหม่',
    'pin.reset.description_otp': 'กรอกรหัส 6 หลักที่ได้รับทาง SMS',
    'pin.reset.description_pin': 'กำหนด PIN 6 หลักใหม่สำหรับเข้าใช้งาน',
    'pin.reset.description_confirm_pin': 'กรอก PIN ใหม่อีกครั้งเพื่อยืนยัน',
    'pin.reset.description_done': 'คุณสามารถใช้งานแอปต่อได้ทันที',
    'pin.reset.request_info':
        'ระบบจะส่ง OTP ไปยังเบอร์โทรศัพท์ที่ผูกกับบัญชีนี้ เพื่อยืนยันตัวตนก่อนตั้ง PIN ใหม่',
    'pin.reset.otp_label': 'รหัส OTP 6 หลัก',
    'pin.reset.otp_sent_to': 'ส่งรหัสไปยัง {phone}',
    'pin.reset.resend_in': 'ส่งใหม่ได้ใน {seconds} วินาที',
    'pin.reset.resend': 'ส่งรหัสใหม่',
    'pin.reset.new_pin_label': 'PIN ใหม่ 6 หลัก',
    'pin.reset.confirm_pin_label': 'ยืนยัน PIN ใหม่',
    'pin.reset.pin_mismatch': 'PIN ไม่ตรงกัน',
    'pin.reset.done_message': 'ตั้งค่า PIN ใหม่เรียบร้อยแล้ว',
    'pin.reset.back_to_app': 'กลับไปใช้งาน',
    'pin.reset.back_to_pin': 'กลับไปกรอก PIN',
    'pin.reset.submit_otp': 'ยืนยัน OTP',
    'pin.reset.save_pin': 'บันทึก PIN ใหม่',
    'pin.reset.send_otp': 'ส่งรหัส OTP',
    'pin.reset.otp_required': 'กรุณากรอก OTP 6 หลัก',
    'pin.reset.pin_required': 'กรุณากรอก PIN 6 หลัก',
    'pin.reset.failed': 'รีเซ็ต PIN ไม่สำเร็จ กรุณาลองใหม่',
    'pin.reset.send_failed': 'ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่',
    'pin.reset.otp_provider_unavailable':
        'ร้านค้ายังไม่ได้เปิดบริการ OTP สำหรับรีเซ็ต PIN กรุณาติดต่อร้านค้าเพื่อยืนยันตัวตน',
    'common.account_phone': 'เบอร์บัญชีของคุณ',
    'security.capture.title': 'ไม่อนุญาตให้บันทึกหน้าจอ',
    'security.capture.description':
        'ระบบซ่อนข้อมูลสำคัญแล้ว กรุณาปลดล็อกอีกครั้งเพื่อใช้งานต่อ',
    'security.capture.unlock_again': 'ปลดล็อกอีกครั้ง',
    'common.view_all': 'ดูทั้งหมด',
    'common.retry': 'ลองใหม่',
    'common.cancel': 'ยกเลิก',
    'common.wallet_balance': 'ยอดเงินในกระเป๋า',
    'common.next': 'ถัดไป',
    'common.confirm': 'ยืนยัน',
    'common.loading_data': 'กำลังโหลดข้อมูล...',
    'common.load_failed': 'โหลดข้อมูลไม่สำเร็จ',
    'home.title': 'หน้าหลัก',
    'home.activities': 'กิจกรรม',
    'home.news': 'ข่าวสาร',
    'home.action.topup': 'เติมเงิน',
    'home.action.tickets': 'สลากฯ',
    'home.action.claim': 'ขึ้นเงิน',
    'home.action.history': 'ประวัติ',
    'home.product_title': 'สลากหกหลัก',
    'home.price.amount': '80',
    'home.price.unit': 'บาท',
    'home.sale.label': 'เปิดขายงวดนี้',
    'home.sale.amount': '30 ล้านใบ!',
    'home.buy_lottery.title': 'ซื้อสลากดิจิทัล',
    'home.buy_lottery.subtitle': 'ค้นหาเลข จองสลาก และไปยังตะกร้า',
    'home.scan_lottery.title': 'สแกนซื้อสลากฯ',
    'home.guest.title': 'เริ่มซื้อสลากดิจิทัล',
    'home.guest.subtitle': 'เข้าสู่ระบบหรือสมัครสมาชิกก่อนเลือกสลากและชำระเงิน',
    'home.results.title': 'ผลรางวัลสลากฯ',
    'home.results.subtitle': 'ดูผลสดอย่างไม่เป็นทางการและผลย้อนหลัง',
    'home.news_card.title': 'ข่าวสาร',
    'home.news_card.subtitle': 'ประกาศและข่าวประชาสัมพันธ์จากร้านค้า',
    'result.title': 'ผลรางวัลสลากฯ',
    'result.full_title': 'ผลรางวัลแบบเต็ม',
    'result.loading': 'กำลังโหลดผลรางวัล...',
    'result.history_title': 'ผลรางวัลสลากฯ ย้อนหลัง',
    'result.no_latest': 'ยังไม่มีข้อมูลผลรางวัลล่าสุด',
    'result.no_history': 'ยังไม่มีข้อมูลผลรางวัลงวดย้อนหลัง',
    'result.no_additional': 'ยังไม่มีข้อมูลเลขรางวัลเพิ่มเติม',
    'result.payout_hint':
        'คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล',
    'result.pending_draw_date': 'รอข้อมูลวันออกผล',
    'result.unofficial': 'ผลรางวัลนี้เป็นผลแสดงสดอย่างไม่เป็นทางการ',
    'result.draw_date': 'งวดวันที่ {date}',
    'result.prize_each': 'รางวัลละ {amount}',
    'result.reward.reward_1': 'รางวัลที่ 1',
    'result.reward.reward_2': 'รางวัลที่ 2',
    'result.reward.reward_3': 'รางวัลที่ 3',
    'result.reward.reward_4': 'รางวัลที่ 4',
    'result.reward.reward_5': 'รางวัลที่ 5',
    'result.reward.reward_beside_1': 'รางวัลข้างเคียงรางวัลที่ 1',
    'result.reward.reward_three_digit_1': 'เลขหน้า 3 ตัว',
    'result.reward.reward_three_digit_2': 'เลขท้าย 3 ตัว',
    'result.reward.reward_two_digit': 'เลขท้าย 2 ตัว',
    'waiting_result.title': 'รอออกผล',
    'waiting_result.sale_closed': 'หมดเวลาจำหน่ายสลากแล้ว',
    'waiting_result.resolved': 'ออกรางวัลแล้ว',
    'waiting_result.pending': 'รอประกาศผลรางวัล',
    'waiting_result.my_tickets': 'สลากของฉัน',
    'waiting_result.check_result': 'ตรวจผลรางวัล',
    'waiting_result.placeholder':
        'ระบบจะแสดงผลรางวัลเป็น xxxxxx จนกว่าจะมีผลประกาศ',
    'waiting_result.live.title': 'ถ่ายทอดสดประกาศผล',
    'waiting_result.live.empty': 'ระบบจะแสดงถ่ายทอดสดเมื่อพร้อมใช้งาน',
    'waiting_result.live.open': 'เปิดถ่ายทอดสด',
    'waiting_result.live.open_failed': 'ไม่สามารถเปิดถ่ายทอดสดได้',
    'maintenance.title': '{site} อยู่ระหว่างปิดปรับปรุง',
    'maintenance.fallback_title': 'ระบบอยู่ระหว่างปิดปรับปรุง',
    'maintenance.default_message':
        'ขออภัยในความไม่สะดวก กรุณากลับมาใหม่อีกครั้ง',
    'maintenance.expected_end': 'คาดว่าจะกลับมาใช้งานได้ {date}',
    'maintenance.support': 'ติดต่อฝ่ายบริการ {phone}',
    'maintenance.support_email': 'ติดต่อฝ่ายบริการ {email}',
    'maintenance.support_online': 'ติดต่อฝ่ายบริการผ่านเว็บไซต์',
    'maintenance.loading_title': 'กำลังโหลดสถานะระบบ',
    'maintenance.loading_message': 'กรุณารอสักครู่',
    'account_suspended.permanent': 'ระงับถาวร',
    'account_suspended.temporary': 'ระงับชั่วคราว',
    'account_suspended.until': 'ถึง {date}',
    'account_suspended.kicker': 'บัญชีถูกระงับการใช้งาน',
    'account_suspended.title': 'ไม่สามารถเข้าใช้งานระบบได้',
    'account_suspended.message':
        'บัญชีสมาชิกนี้ถูกระงับโดยร้านค้า กรุณาตรวจสอบเหตุผลด้านล่างหรือติดต่อฝ่ายบริการ',
    'account_suspended.reason': 'เหตุผล',
    'account_suspended.no_reason': 'ไม่ได้ระบุเหตุผล',
    'account_suspended.duration': 'ระยะเวลาระงับ',
    'account_suspended.back_to_login': 'กลับไปหน้าเข้าสู่ระบบ',
    'account_suspended.contact_support': 'ติดต่อฝ่ายบริการ',
    'account_suspended.contact_support_online': 'ติดต่อฝ่ายบริการผ่านเว็บไซต์',
    'account_suspended.contact_support_with_phone': 'ติดต่อฝ่ายบริการ {phone}',
    'account_suspended.contact_support_with_email': 'ติดต่อฝ่ายบริการ {email}',
    'countdown.title': 'รอเปิดขาย',
    'countdown.waiting_title': 'รอเปิดงวดใหม่',
    'countdown.opens_in': 'จะเปิดขายในอีก',
    'countdown.current_draw_fallback': 'งวดปัจจุบัน',
    'countdown.sale_opens_at': 'เปิดขาย {date}',
    'countdown.load_failed': 'โหลดข้อมูลงวดไม่สำเร็จ',
    'countdown.unit.day': 'วัน',
    'countdown.unit.hour': 'ชั่วโมง',
    'countdown.unit.minute': 'นาที',
    'countdown.unit.second': 'วินาที',
    'success.title': 'ทำรายการสำเร็จ',
    'success.lottery_product_label': '',
    'success.purchase_title': 'ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ',
    'success.purchase_subtitle': 'คุณสามารถดูสลากฯ ได้ที่เมนู สลากฯ ของฉัน',
    'success.view_tickets': 'ดูสลากฯ ของฉัน',
    'success.save_receipt': 'บันทึก',
    'success.receipt_saved': 'บันทึกข้อมูลการชำระเงินแล้ว',
    'success.share_receipt': 'แชร์',
    'success.receipt_share_started': 'เปิดตัวเลือกการแชร์แล้ว',
    'success.receipt_share_failed_copied':
        'แชร์ใบเสร็จไม่สำเร็จ จึงคัดลอกข้อมูลให้แล้ว',
    'success.payment_loading': 'กำลังโหลดข้อมูลการชำระเงิน...',
    'success.payment_load_failed': 'โหลดข้อมูลการชำระเงินไม่สำเร็จ',
    'success.transaction_at_label': 'วันที่ทำรายการ',
    'news.title': 'ข่าวสาร',
    'news.detail_title': 'รายละเอียดข่าวสาร',
    'news.category': 'ข่าวประชาสัมพันธ์',
    'news.fallback_title': 'ข่าวประชาสัมพันธ์',
    'news.loading': 'กำลังโหลดข่าวสาร',
    'news.load_failed.title': 'โหลดข่าวสารไม่สำเร็จ',
    'news.load_failed.message': 'กรุณาลองใหม่อีกครั้ง',
    'news.empty.title': 'ยังไม่มีข่าวสาร',
    'news.empty.message': 'ข่าวและประกาศจากร้านค้าจะแสดงที่นี่',
    'news.missing.title': 'ไม่พบข่าวประชาสัมพันธ์',
    'news.missing.message': 'ข่าวนี้อาจหมดช่วงเวลาแสดงผลหรือถูกปิดใช้งานแล้ว',
    'news.back_to_list': 'กลับหน้าข่าวสาร',
    'news.missing': 'ไม่พบข่าวสารนี้',
    'news.open_failed': 'เปิดข่าวสารไม่สำเร็จ',
    'news.modal.close': 'ปิดข่าวประชาสัมพันธ์',
    'content.terms.title': 'ข้อตกลงและเงื่อนไข',
    'content.terms.site_fallback': 'เว็บไซต์นี้',
    'content.terms.section_title': 'ข้อตกลงการใช้งาน',
    'content.terms.default_content': 'ข้อตกลงการใช้งาน\n'
        '1. {site}เป็นระบบจำหน่ายลอตเตอรี่ออนไลน์\n'
        '2. บริษัทไม่สนับสนุนการจำหน่ายสลากให้กับบุคคลที่มีอายุไม่ถึง 20 ปี\n'
        '3. บริษัทสนับสนุนผู้ไม่มีรายได้ ผู้พิการ ในการเป็นตัวแทนจำหน่ายลอตเตอรี่ออนไลน์\n'
        '4. บริษัทเก็บรักษาสลากที่ลูกค้าซื้อเพื่อความปลอดภัย รวมถึงการขึ้นรางวัลให้กับลูกค้า\n'
        '5. หากผู้ซื้อนำรูปภาพสลากหรือสลากจริงไปขายต่อ ทางบริษัทไม่มีส่วนเกี่ยวข้องและไม่รับผิดชอบความเสียหายในทุกกรณี\n'
        '6. หลังจาก ทำรายการ และ กดปุ่ม " ชำระเงิน " ทางบริษัทถือว่า ผู้สั่งซื้อได้รับทราบ ข้อตกลงและเงื่อนไขต่างๆของบริษัทเป็นที่เรียบร้อย\n'
        '7. บริษัทขอสงวนสิทธิ์ ขึ้นเงินรางวัลให้ลูกค้าที่ซื้อกับระบบ ในกรณีลูกค้าถูกรางวัล โดยไม่มีค่าใช้จ่ายใดๆ ทั้งสิ้น\n'
        '8. ลูกค้าสามารถยกเลิกการสั่งซื้อสลากได้ภายใน 15 นาทีทุกกรณี หากเกินระยะเวลาที่กำหนด บริษัทขอสงวนสิทธิ์ไม่คืนเงินค่าสลากทุกกรณี',
    'content.privacy.title': 'นโยบายความเป็นส่วนตัว',
    'content.privacy.section_title': 'การคุ้มครองข้อมูล',
    'content.privacy.hero_subtitle': 'วิธีที่ {site} ดูแลข้อมูลส่วนบุคคลของคุณ',
    'content.privacy.default_content': 'นโยบายความเป็นส่วนตัว\n'
        '1. {site} ใช้ข้อมูลส่วนบุคคลเพื่อให้บริการซื้อสลาก เติมเงิน รับเงินรางวัล และแจ้งเตือนรายการ\n'
        '2. ระบบเก็บข้อมูลเท่าที่จำเป็นตามกฎหมายและมาตรฐานความปลอดภัย\n'
        '3. ลูกค้าสามารถติดต่อร้านค้าเพื่อขอแก้ไข ส่งออก หรือลบข้อมูลบัญชีได้\n'
        '4. การลบบัญชีอาจยังต้องเก็บข้อมูลธุรกรรมที่กฎหมายกำหนดไว้',
    'content.privacy.open_policy': 'เปิดนโยบายฉบับเต็ม',
    'content.privacy.open_failed': 'เปิดนโยบายไม่สำเร็จ',
    'content.reward_terms.title': 'เงื่อนไขเงินรางวัล',
    'content.reward_terms.hero.title': 'รายละเอียดเงินรางวัล',
    'content.reward_terms.hero.subtitle':
        'สลากดิจิทัลหกหลักแบบดิจิทัล 1 ชุด มี 1 ล้านฉบับ ฉบับละ 80 บาท',
    'content.reward_terms.office.abbr': 'GLO',
    'content.reward_terms.office.name':
        'สำนักงานสลากกินแบ่งรัฐบาล\nTHE GOVERNMENT LOTTERY OFFICE',
    'content.reward_terms.header.prize_type': 'ประเภทรางวัล',
    'content.reward_terms.header.count': 'จำนวน',
    'content.reward_terms.header.amount': 'มูลค่ารางวัลละ',
    'content.reward_terms.row.first.title': 'รางวัลที่ 1',
    'content.reward_terms.row.first.count': '1 รางวัล',
    'content.reward_terms.row.first.amount': '6,000,000 บาท',
    'content.reward_terms.row.second.title': 'รางวัลที่ 2',
    'content.reward_terms.row.second.count': '5 รางวัล',
    'content.reward_terms.row.second.amount': '200,000 บาท',
    'content.reward_terms.row.third.title': 'รางวัลที่ 3',
    'content.reward_terms.row.third.count': '10 รางวัล',
    'content.reward_terms.row.third.amount': '80,000 บาท',
    'content.reward_terms.row.fourth.title': 'รางวัลที่ 4',
    'content.reward_terms.row.fourth.count': '50 รางวัล',
    'content.reward_terms.row.fourth.amount': '40,000 บาท',
    'content.reward_terms.row.fifth.title': 'รางวัลที่ 5',
    'content.reward_terms.row.fifth.count': '100 รางวัล',
    'content.reward_terms.row.fifth.amount': '20,000 บาท',
    'content.reward_terms.row.adjacent_first.title':
        'รางวัลข้างเคียง\nรางวัลที่ 1',
    'content.reward_terms.row.adjacent_first.count': '2 รางวัล',
    'content.reward_terms.row.adjacent_first.amount': '100,000 บาท',
    'content.reward_terms.row.front3.title': 'เลขหน้า 3 ตัว',
    'content.reward_terms.row.front3.count': 'เสี่ยง 2 ครั้ง\n2,000 รางวัล',
    'content.reward_terms.row.front3.amount': '4,000 บาท',
    'content.reward_terms.row.last3.title': 'เลขท้าย 3 ตัว',
    'content.reward_terms.row.last3.count': 'เสี่ยง 2 ครั้ง\n2,000 รางวัล',
    'content.reward_terms.row.last3.amount': '4,000 บาท',
    'content.reward_terms.row.last2.title': 'เลขท้าย 2 ตัว',
    'content.reward_terms.row.last2.count': 'เสี่ยง 1 ครั้ง\n10,000 รางวัล',
    'content.reward_terms.row.last2.amount': '2,000 บาท',
    'content.knowledge.title': 'ข้อควรรู้การซื้อ-ขายสลากฯ',
    'content.knowledge.subtitle':
        'ข้อมูลสำคัญสำหรับผู้ซื้อและผู้จำหน่ายสลากดิจิทัล',
    'content.knowledge.more_info': 'ศึกษารายละเอียดเพิ่มเติม ได้ที่',
    'content.knowledge.contact': 'www.glo.or.th หรือโทร 02-528-9682',
    'content.knowledge.section.digital_lottery.title': 'สลากหกหลักแบบดิจิทัล',
    'content.knowledge.section.digital_lottery.item_1':
        'ห้ามนำสลากหกหลักแบบดิจิทัลไปขายต่อผ่านช่องทางอื่น',
    'content.knowledge.section.digital_lottery.item_2':
        'ผู้ซื้อมีสิทธิ์หรือเป็นเจ้าของสลากหกหลักแบบดิจิทัลเมื่อทำรายการซื้อสำเร็จและไม่สามารถโอนสิทธิ์ให้กับผู้อื่นได้',
    'content.knowledge.section.digital_lottery.item_3':
        'การซื้อสลากหกหลักแบบดิจิทัล ผ่านแอปฯ เป๋าตัง ช่วยป้องกันการถูกฉ้อโกงจากมิจฉาชีพ',
    'content.knowledge.section.sellers.title':
        'สำหรับผู้จำหน่ายสลากกินแบ่งรัฐบาล',
    'content.knowledge.section.sellers.item_1':
        'ห้ามขายสลากฯ ในราคาเกินกว่าที่สำนักงานสลากกินแบ่งรัฐบาลกำหนด',
    'content.knowledge.section.sellers.item_2': 'ห้ามขายสลากฯ ในสถานศึกษา',
    'content.knowledge.section.sellers.item_3':
        'ห้ามขายสลากฯ ให้แก่บุคคลที่มีอายุต่ำกว่า 20 ปีบริบูรณ์',
    'lottery.buy.title': 'ซื้อสลากดิจิทัล',
    'lottery.cart.tooltip': 'ตะกร้าสลาก',
    'lottery.search.hero_title': 'ค้นหาเลขเด็ด',
    'lottery.search.hero_subtitle': 'กรอกบางหลักหรือครบ 6 หลักเพื่อค้นหาสลาก',
    'lottery.search.button': 'ค้นหาเลข',
    'lottery.search.loading': 'กำลังค้นหา',
    'lottery.search.clear': 'ล้างค่า',
    'lottery.stock.title': 'เลขสลากดิจิทัล',
    'lottery.stock.subtitle': 'ระบบสุ่มสลับรายการทุกครั้งที่โหลดใหม่',
    'lottery.filter.all': 'ทั้งหมด',
    'lottery.filter.discount': 'ลดราคา',
    'lottery.filter.accessible_store': 'ร้านค้าผู้พิการ',
    'lottery.filter.agency_store': 'ร้านค้าหน่วยงาน',
    'lottery.search.page_title': 'ซื้อสลากดิจิทัล',
    'lottery.search.card_title': 'ค้นหาเลขเด็ด',
    'lottery.search.store_card_title': 'ค้นหาเลขสลากฯในร้านค้า',
    'lottery.search.number_label': 'เลขที่ต้องการ',
    'lottery.search.again': 'ค้นหาใหม่',
    'lottery.search.results_title': 'ผลการค้นหาเลข',
    'lottery.search.results_subtitle':
        'กดดูเลขนี้เพิ่มเติมเพื่อค้นหาเลขเดียวกันอีกครั้ง',
    'lottery.more.title': 'ดูเลขนี้เพิ่มเติม',
    'lottery.more.sheet_title': 'รายการสลากฯ',
    'lottery.more.number_prefix': 'สลากฯ เลข',
    'lottery.more.fallback': 'เลขสลากเพิ่มเติม',
    'lottery.more.subtitle': 'รายการถูกสุ่มสลับเพื่อไม่ให้เลขเรียงกัน',
    'lottery.more.list_title': 'เลขนี้เพิ่มเติม',
    'lottery.stock.show_new': 'แสดงเลขใหม่',
    'lottery.stock.loading_new': 'กำลังโหลด',
    'lottery.stock.refresh_cooldown': 'รอ {seconds} วิ',
    'lottery.stock.load_failed': 'โหลดเลขสลากไม่สำเร็จ',
    'lottery.stock.not_found.title': 'ไม่พบเลขสลาก',
    'lottery.stock.not_found.message': 'ลองค้นหาเลขอื่น หรือกลับมาใหม่อีกครั้ง',
    'lottery.stock.added_to_cart': 'เพิ่มสลากลงตะกร้าแล้ว',
    'lottery.stock.removed_from_cart': 'นำสลากออกจากตะกร้าแล้ว',
    'lottery.stock.cart_action': 'ตะกร้า',
    'lottery.stock.action_failed': 'ทำรายการไม่สำเร็จ',
    'lottery.stock.reservation_unavailable.title': 'สลากใบนี้ถูกซื้อแล้ว',
    'lottery.stock.reservation_unavailable.message':
        'ขออภัย สลากที่ท่านเลือกมีคนซื้อแล้ว กรุณาเลือกสลากใบอื่น',
    'lottery.stock.reservation_unavailable.action': 'รับทราบ',
    'lottery.stock.view_more': 'ดูเลขนี้เพิ่ม',
    'lottery.stock.select': 'เลือก',
    'lottery.stock.selecting': 'กำลังจอง',
    'lottery.stock.sold_out': 'ขายหมดแล้ว',
    'lottery.stock.sale_closed.title': 'ขณะนี้ไม่สามารถซื้อสลากได้',
    'lottery.stock.sale_closed.message':
        'ระบบปิดรับการจองสลากสำหรับงวดนี้แล้ว คุณยังสามารถดูรายการหรือไปยังตะกร้าที่จองไว้ได้',
    'lottery.stock.sale_closed.action': 'ปิดรับซื้อ',
    'lottery.stock.remove': 'เอาออก',
    'lottery.stock.removing': 'กำลังลบ',
    'cart.title': 'ตรวจสอบรายการสลากฯ',
    'cart.reserved_title': 'รายการที่จองไว้',
    'cart.empty_subtitle': 'ยังไม่มีสลากในตะกร้า',
    'cart.header_count': 'สลากฯ {count} ใบ',
    'cart.summary': '{count} ใบ • {total}',
    'cart.draw_date': 'งวดวันที่ {date}',
    'cart.load_failed_title': 'โหลดตะกร้าไม่สำเร็จ',
    'cart.loading': 'กำลังโหลดรายการสลากในตะกร้า...',
    'cart.empty_title': 'ตะกร้าว่าง',
    'cart.empty_message': 'เลือกสลากที่ต้องการก่อนชำระเงิน',
    'cart.find_tickets': 'ค้นหาเลขสลาก',
    'cart.selection.title': 'คุณมีสลากฯ ที่เลือกไว้',
    'cart.selection.count_label': 'จำนวนที่เลือก',
    'cart.selection.review': 'ตรวจสอบสลากฯ',
    'cart.purchase_limit_message':
        'คุณสามารถเลือกซื้อสลากฯ ได้สูงสุด 20 ใบ\nต่อการทำรายการซื้อ 1 ครั้ง',
    'cart.add_more_tickets': 'เลือกสลากฯ เพิ่ม',
    'cart.checkout': 'ชำระเงิน',
    'cart.generic_retry': 'กรุณาลองใหม่อีกครั้ง',
    'cart.remove_group_title.single': 'คุณต้องการลบสลากฯ\n{number} หรือไม่',
    'cart.remove_group_title.multiple':
        'คุณต้องการลบสลากฯ\n{number} จำนวน {count} ใบ หรือไม่',
    'cart.remove_group_message.single':
        'เมื่อยืนยัน สลากฯ ใบนี้\nจะถูกลบออกจากรายการซื้อ',
    'cart.remove_group_message.multiple':
        'เมื่อยืนยัน สลากฯ ชุดนี้\nจะถูกลบออกจากรายการซื้อ',
    'cart.remove_group_confirm': 'ลบ',
    'cart.remove_group_removing': 'กำลังลบ',
    'cart.reservation_title': 'รายการจอง {count} ใบ',
    'cart.expires_in': 'หมดเวลาจองใน {minutes} นาที',
    'cart.expires_countdown': 'กรุณาชำระเงินภายใน {time}',
    'cart.expired': 'หมดเวลาชำระเงิน',
    'cart.expired_release_message': 'ระบบยกเลิกการจองสลากในตะกร้านี้แล้ว',
    'checkout.title': 'ยืนยันการชำระเงิน',
    'checkout.summary_title': 'สรุปรายการ',
    'checkout.ticket_count': 'จำนวนสลากฯ',
    'checkout.summary_total': 'ยอดชำระทั้งหมด',
    'checkout.total': 'ยอดชำระ',
    'checkout.wallet_balance': 'ยอดเงินในกระเป๋า',
    'checkout.payment_method_title': 'ช่องทางชำระเงิน',
    'checkout.wallet_fallback_name': 'G Wallet',
    'checkout.wallet_payment_note':
        'คุณสามารถยืนยันชำระเงินเพื่อใช้บัญชีที่ผูกไว้ชำระเงินค่าสลากได้อัตโนมัติ',
    'checkout.wallet_loading': 'กำลังโหลดกระเป๋าเงิน...',
    'checkout.wallet_load_failed': 'โหลดกระเป๋าเงินไม่สำเร็จ',
    'checkout.external_payment.name': 'ชำระผ่านผู้ให้บริการภายนอก',
    'checkout.external_payment.subtitle':
        'เปิดหน้าชำระเงินของผู้ให้บริการที่ร้านค้ากำหนด',
    'checkout.external_payment.note':
        'ระบบจะสร้างรายการรอชำระและเปิดหน้าชำระเงินภายนอกเมื่อยืนยัน',
    'checkout.open_payment_failed': 'เปิดหน้าชำระเงินไม่สำเร็จ',
    'checkout.pending.title': 'รอชำระเงิน',
    'checkout.pending.loading': 'กำลังตรวจสอบสถานะการชำระเงิน...',
    'checkout.pending.message':
        'ระบบสร้างรายการชำระเงินแล้ว กรุณาชำระเงินผ่านหน้าผู้ให้บริการภายนอก เมื่อชำระสำเร็จแล้วจึงกลับมาตรวจสอบสถานะอีกครั้ง',
    'checkout.pending.paid_title': 'ชำระเงินสำเร็จแล้ว',
    'checkout.pending.paid_message':
        'ระบบได้รับสถานะชำระเงินของรายการนี้แล้ว คุณสามารถดูใบเสร็จได้ทันที',
    'checkout.pending.no_order_title': 'ไม่พบรายการรอชำระ',
    'checkout.pending.no_order_message':
        'กรุณากลับไปหน้าชำระเงินหรือเลือกสลากใหม่อีกครั้ง',
    'checkout.pending.reference_label': 'เลขที่รายการ',
    'checkout.pending.status_label': 'สถานะ',
    'checkout.pending.amount_label': 'ยอดชำระ',
    'checkout.pending.open_payment': 'เปิดหน้าชำระเงิน',
    'checkout.pending.refresh': 'ตรวจสอบสถานะอีกครั้ง',
    'checkout.pending.view_receipt': 'ดูใบเสร็จ',
    'checkout.pending.status.pending': 'รอชำระ',
    'checkout.pending.status.paid': 'ชำระแล้ว',
    'checkout.pending.status.failed': 'ชำระไม่สำเร็จ',
    'checkout.pending.status.expired': 'หมดอายุ',
    'checkout.pending.status.unknown': 'กำลังตรวจสอบ',
    'checkout.payment_timer': 'กรุณาชำระเงินภายใน {time}',
    'checkout.load_failed_title': 'โหลดข้อมูลไม่สำเร็จ',
    'checkout.preparing': 'กำลังเตรียมรายการชำระเงิน...',
    'checkout.no_payment_title': 'ไม่มีรายการชำระเงิน',
    'checkout.no_payment_message': 'ตะกร้าว่างหรือรายการจองหมดอายุแล้ว',
    'checkout.back_to_buy': 'กลับไปเลือกสลาก',
    'checkout.insufficient.title': 'ยอดเงินไม่เพียงพอ',
    'checkout.insufficient.subtitle': 'เติมเงินก่อนชำระค่าสลาก',
    'checkout.submitting': 'กำลังชำระเงิน',
    'checkout.confirm': 'ยืนยันชำระเงิน',
    'checkout.failed': 'ชำระเงินไม่สำเร็จ',
    'profile.title': 'อื่นๆ',
    'profile.refresh_tooltip': 'รีเฟรชข้อมูล',
    'profile.customer_account': 'บัญชีลูกค้า',
    'profile.member_code': 'รหัสสมาชิก : {code}',
    'profile.copy_member_code': 'คัดลอกรหัสสมาชิก',
    'profile.copied_member_code': 'คัดลอกรหัสสมาชิกแล้ว',
    'profile.loading': 'กำลังโหลดข้อมูลสมาชิก...',
    'profile.load_failed': 'โหลดข้อมูลสมาชิกไม่สำเร็จ',
    'profile.refresh_again': 'กรุณาลองรีเฟรชอีกครั้ง',
    'profile.language.title': 'ภาษาในการใช้งาน',
    'profile.language.subtitle': 'เลือกภาษาสำหรับหน้าแอปและข้อความจากระบบ',
    'profile.language.save_failed':
        'เปลี่ยนภาษาแล้ว แต่ยังบันทึกลงบัญชีไม่สำเร็จ',
    'profile.section.history': 'ประวัติ',
    'profile.section.reward_settings': 'ตั้งค่ารับเงินรางวัล',
    'profile.section.about': 'เกี่ยวกับแอปฯ',
    'profile.badge.new': 'ใหม่',
    'profile.badge.recommended': 'แนะนำ',
    'profile.menu.reward_bank': 'บัญชีรับเงินรางวัล',
    'profile.menu.how_to_contact': 'วิธีซื้อขายสลากฯ และการติดต่อ',
    'profile.reward_bank.load_failed': 'โหลดบัญชีรับเงินไม่สำเร็จ',
    'profile.reward_bank.incomplete':
        'กรุณาเลือกธนาคาร กรอกชื่อบัญชี และเลขบัญชี',
    'profile.reward_bank.saved': 'บันทึกบัญชีรับเงินแล้ว',
    'profile.reward_bank.save_failed':
        'บันทึกบัญชีไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่',
    'profile.reward_bank.pin_invalid': 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง',
    'profile.reward_bank.pin_locked':
        'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่',
    'profile.reward_bank.pin_required': 'กรุณาตั้งค่าหรือยืนยัน PIN ก่อนบันทึก',
    'profile.reward_bank.hero.title': 'ช่องทางรับเงิน',
    'profile.reward_bank.hero.subtitle':
        'ใช้สำหรับรับเงินรางวัลและถอนค่าคอมมิชชัน',
    'profile.reward_bank.form.title': 'ข้อมูลบัญชีธนาคาร',
    'profile.reward_bank.form.description':
        'เลือกชื่อธนาคารในประเทศไทย และกรอกชื่อบัญชีกับเลขบัญชีให้ตรงกับสมุดบัญชี',
    'profile.reward_bank.form.bank': 'ธนาคาร',
    'profile.reward_bank.form.bank_options':
        'ธนาคารกรุงเทพ|ธนาคารกสิกรไทย|ธนาคารกรุงไทย|ธนาคารทหารไทยธนชาต|ธนาคารไทยพาณิชย์|ธนาคารกรุงศรีอยุธยา|ธนาคารเกียรตินาคินภัทร|ธนาคารซีไอเอ็มบี ไทย|ธนาคารทิสโก้|ธนาคารยูโอบี|ธนาคารไทยเครดิต|ธนาคารแลนด์ แอนด์ เฮ้าส์|ธนาคารไอซีบีซี (ไทย)|ธนาคารออมสิน|ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร|ธนาคารอาคารสงเคราะห์|ธนาคารอิสลามแห่งประเทศไทย|ธนาคารพัฒนาวิสาหกิจขนาดกลางและขนาดย่อมแห่งประเทศไทย',
    'profile.reward_bank.form.account_name': 'ชื่อบัญชี',
    'profile.reward_bank.form.account_name_hint': 'ชื่อเจ้าของบัญชี',
    'profile.reward_bank.form.account_number': 'เลขบัญชี',
    'profile.reward_bank.form.account_number_hint': 'เลขบัญชีธนาคาร',
    'profile.reward_bank.form.save': 'บันทึกบัญชีรับเงิน',
    'profile.reward_bank.preview.empty_title': 'ยังไม่ได้บันทึกบัญชีรับเงิน',
    'profile.reward_bank.preview.empty_subtitle':
        'บัญชีนี้จะถูกใช้ร่วมกันทั้งเงินรางวัลและ Affiliate',
    'profile.reward_bank.pin.title': 'ใส่รหัส PIN 6 หลัก',
    'profile.reward_bank.pin.subtitle': 'เพื่อบันทึกบัญชีรับเงินรางวัล',
    'profile.menu.auto_reward': 'ขึ้นเงินรางวัลอัตโนมัติ',
    'profile.auto_reward.load_failed': 'โหลดข้อมูลไม่สำเร็จ',
    'profile.auto_reward.save_bank_first':
        'กรุณาเพิ่มบัญชีรับเงินก่อนเลือกบัญชีธนาคาร',
    'profile.auto_reward.add_bank_first': 'กรุณาเพิ่มบัญชีรับเงินก่อน',
    'profile.auto_reward.saved': 'ตั้งค่าขึ้นเงินรางวัลอัตโนมัติแล้ว',
    'profile.auto_reward.save_failed': 'บันทึกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
    'profile.auto_reward.intro.subtitle': 'สะดวก ง่าย ได้เงินเร็ว',
    'profile.auto_reward.visual.credit_label': 'เงินเข้า',
    'profile.auto_reward.visual.credit_amount': '+3,940',
    'profile.auto_reward.visual.credit_currency': 'บาท',
    'profile.auto_reward.benefit.convenient': 'สะดวก ไม่ต้องขึ้นรางวัลเอง',
    'profile.auto_reward.benefit.easy':
        'ง่าย โอนเงินเข้า G Wallet หรือบัญชีธนาคาร',
    'profile.auto_reward.benefit.fast':
        'ได้เงินเร็ว หลัง {reviewer} ตรวจสอบรายการ',
    'profile.auto_reward.reviewer_fallback': 'ผู้ให้บริการ',
    'profile.auto_reward.conditions.title': 'เงื่อนไขการตั้งค่า',
    'profile.auto_reward.conditions.auto_claim':
        'ระบบจะขึ้นเงินรางวัลสลากดิจิทัลทุกใบที่ถูกรางวัล และโอนเงินไปยังช่องทางรับเงินหลักที่เลือกไว้โดยอัตโนมัติ',
    'profile.auto_reward.conditions.fee':
        'ธนาคารจะคิดค่าบริการในการขึ้นเงินรางวัลสลากดิจิทัลผ่านการรับเงินเข้าบัญชีธนาคารหรือ Wallet',
    'profile.auto_reward.conditions.change_before':
        'หากต้องการเปลี่ยนช่องทางรับเงิน กรุณาตั้งค่าก่อนเวลา 16:00 น. ของวันออกรางวัล',
    'profile.auto_reward.conditions.no_retroactive':
        'การตั้งค่านี้จะไม่มีผลต่อสลากดิจิทัลที่ถูกรางวัลในงวดย้อนหลัง',
    'profile.auto_reward.start_button': 'ตั้งค่าขึ้นเงินรางวัลอัตโนมัติ',
    'profile.auto_reward.info_tooltip': 'ข้อมูล',
    'profile.auto_reward.select.title': 'เลือกช่องทางรับเงินรางวัลหลัก',
    'profile.auto_reward.select.subtitle':
        'ระบบจะขึ้นเงินรางวัลสลากฯ และส่งรายการให้ {reviewer} ตามช่องทางรับเงินหลักที่เลือกไว้โดยอัตโนมัติ',
    'profile.auto_reward.wallet.title': 'G Wallet',
    'profile.auto_reward.wallet.subtitle':
        'วงเงิน G Wallet รับได้สูงสุด 500,000 บาท',
    'profile.auto_reward.bank.title': 'บัญชีธนาคาร',
    'profile.auto_reward.bank.missing_subtitle':
        'กรุณาเพิ่มบัญชีรับเงินก่อนเลือกช่องทางนี้',
    'profile.auto_reward.bank.missing_helper': 'ยังไม่มีบัญชีรับเงิน',
    'profile.auto_reward.pin.title': 'ใส่รหัส PIN 6 หลัก',
    'profile.auto_reward.pin.subtitle':
        'เพื่อยืนยันการตั้งค่าขึ้นเงินรางวัลอัตโนมัติ',
    'profile.menu.line_notifications': 'แจ้งเตือนผ่าน LINE',
    'profile.line_notifications.hero.title': 'รับแจ้งเตือนทุกการทำรายการ',
    'profile.line_notifications.hero.subtitle':
        'เติมเงิน ซื้อสลาก เข้าร่วมกิจกรรม และสถานะการขึ้นเงินรางวัลจากร้านค้านี้',
    'profile.line_notifications.store_unavailable.title':
        'ร้านค้านี้ยังไม่ได้เปิดใช้งาน LINE OA',
    'profile.line_notifications.store_unavailable.message':
        'เมื่อร้านค้าตั้งค่าเรียบร้อย คุณจะเชื่อมต่อและเปิดรับแจ้งเตือนได้ทันที',
    'profile.line_notifications.reconnect': 'เชื่อมต่อ LINE ใหม่',
    'profile.line_notifications.connect': 'เชื่อมต่อ LINE',
    'profile.line_notifications.add_friend': 'เพิ่มเพื่อน LINE OA',
    'profile.line_notifications.disconnect': 'ยกเลิกการเชื่อมต่อ',
    'profile.line_notifications.connect_failed':
        'เชื่อมต่อ LINE ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
    'profile.line_notifications.save_failed': 'บันทึกการแจ้งเตือนไม่สำเร็จ',
    'profile.line_notifications.disconnected': 'ยกเลิกการเชื่อมต่อ LINE แล้ว',
    'profile.line_notifications.disconnect_failed':
        'ยกเลิกการเชื่อมต่อไม่สำเร็จ',
    'profile.line_notifications.missing_url': 'ไม่พบ URL สำหรับเชื่อมต่อ',
    'profile.line_notifications.connected_title': 'เชื่อมต่อ LINE แล้ว',
    'profile.line_notifications.not_connected_title': 'ยังไม่ได้เชื่อมต่อ LINE',
    'profile.line_notifications.connect_once':
        'เชื่อมต่อครั้งเดียว แล้วรับแจ้งเตือนได้ทันที',
    'profile.line_notifications.ready': 'พร้อมใช้',
    'profile.line_notifications.not_linked': 'ยังไม่เชื่อม',
    'profile.line_notifications.status.notification': 'แจ้งเตือน',
    'profile.line_notifications.status.notification_on': 'เปิดอยู่',
    'profile.line_notifications.status.notification_off': 'ยังไม่เปิด',
    'profile.line_notifications.status.friend': 'เพิ่มเพื่อน OA',
    'profile.line_notifications.status.friend_added': 'เพิ่มแล้ว',
    'profile.line_notifications.status.friend_missing': 'ยังไม่เพิ่ม',
    'profile.line_notifications.toggle.title': 'รับแจ้งเตือนผ่าน LINE',
    'profile.line_notifications.toggle.subtitle':
        'เปิดไว้เพื่อรับสถานะรายการสำคัญแบบอัตโนมัติ',
    'profile.line_notifications.events.title': 'รายการที่จะส่งแจ้งเตือน',
    'profile.line_notifications.events.subtitle':
        'ข้อความจะส่งจาก LINE OA ของร้านค้า',
    'profile.line_notifications.events.topup': 'เติมเงินและอัปเดตสถานะเติมเงิน',
    'profile.line_notifications.events.order': 'ซื้อสลากและยืนยันคำสั่งซื้อ',
    'profile.line_notifications.events.activity': 'เข้าร่วมกิจกรรมของร้านค้า',
    'profile.line_notifications.events.reward':
        'ขึ้นเงินรางวัลและสถานะการจ่ายเงิน',
    'profile.line_notifications.load_failed': 'โหลดข้อมูล LINE ไม่สำเร็จ',
    'profile.menu.biometrics': 'Face ID / Biometric',
    'profile.biometric.enabled': 'เปิดใช้ biometric สำหรับเครื่องนี้แล้ว',
    'profile.biometric.enable_failed':
        'เปิดใช้ biometric ไม่สำเร็จ กรุณาตรวจสอบ PIN หรือลองใหม่',
    'profile.biometric.revoke_dialog.title': 'ยกเลิกอุปกรณ์นี้?',
    'profile.biometric.revoke_dialog.message':
        'อุปกรณ์ "{device}" จะไม่สามารถใช้ Face ID / Biometric แทน PIN ได้อีก',
    'profile.biometric.revoked': 'ยกเลิกอุปกรณ์แล้ว',
    'profile.biometric.revoke_failed': 'ยกเลิกอุปกรณ์ไม่สำเร็จ',
    'profile.biometric.pin_dialog.title': 'ยืนยัน PIN 6 หลัก',
    'profile.biometric.setup_reason':
        'ยืนยัน biometric เพื่อเปิดใช้แทน PIN บนอุปกรณ์นี้',
    'profile.biometric.device_name.ios': 'iPhone / iPad เครื่องนี้',
    'profile.biometric.device_name.android': 'Android เครื่องนี้',
    'profile.biometric.device_name.fallback': 'อุปกรณ์เครื่องนี้',
    'profile.biometric.intro.title': 'ใช้ Face ID / Biometric แทน PIN',
    'profile.biometric.intro.subtitle':
        'ต้องยืนยัน PIN 6 หลักหนึ่งครั้งก่อนเปิดใช้ และสามารถยกเลิกอุปกรณ์ได้ทุกเมื่อ',
    'profile.biometric.enable.unavailable_title':
        'เครื่องนี้ยังใช้ biometric ไม่ได้',
    'profile.biometric.enable.title': 'เปิดใช้บนเครื่องนี้',
    'profile.biometric.enable.unavailable_message':
        'ตรวจสอบว่าอุปกรณ์ตั้งค่า Face ID, Touch ID หรือสแกนนิ้วไว้แล้ว',
    'profile.biometric.enable.message':
        'เมื่อเปิดใช้แล้ว หน้าที่ยืนยัน PIN จะสามารถใช้ biometric เพื่อสร้าง token ยืนยันตัวตนแบบอายุสั้นแทนได้',
    'profile.biometric.enable.saving': 'กำลังบันทึก...',
    'profile.biometric.enable.button': 'เปิดใช้ biometric',
    'profile.biometric.empty.title': 'ยังไม่มีอุปกรณ์ biometric',
    'profile.biometric.empty.message':
        'เปิดใช้บนเครื่องนี้เพื่อยืนยันตัวตนได้เร็วขึ้นโดยยังมี PIN เป็นวิธีกู้คืน',
    'profile.biometric.active_devices': 'อุปกรณ์ที่เปิดใช้',
    'profile.biometric.no_active_devices': 'ไม่มีอุปกรณ์ที่เปิดใช้งานอยู่',
    'profile.biometric.revoked_devices': 'ประวัติอุปกรณ์ที่ยกเลิก',
    'profile.biometric.status.active': 'เปิดใช้งาน',
    'profile.biometric.status.revoked': 'ยกเลิกแล้ว',
    'profile.biometric.status.current_device': 'เครื่องนี้',
    'profile.biometric.never_used': 'ยังไม่เคยใช้',
    'profile.biometric.meta.registered': 'ลงทะเบียน',
    'profile.biometric.meta.last_used': 'ใช้งานล่าสุด',
    'profile.biometric.revoke_device': 'ยกเลิกอุปกรณ์นี้',
    'profile.biometric.load_failed': 'โหลดอุปกรณ์ biometric ไม่สำเร็จ',
    'profile.menu.purchase_history': 'ประวัติการซื้อสลาก',
    'profile.menu.news_all': 'ข่าวสารทั้งหมด',
    'profile.menu.terms': 'ข้อตกลงและเงื่อนไข',
    'profile.menu.privacy_policy': 'นโยบายความเป็นส่วนตัว',
    'profile.menu.account_deletion': 'ลบบัญชีผู้ใช้',
    'profile.logout': 'ออกจากระบบ',
    'account_deletion.title': 'ลบบัญชีผู้ใช้',
    'account_deletion.hero.title': 'คำขอลบบัญชี',
    'account_deletion.hero.subtitle': 'ส่งคำขอลบบัญชีและข้อมูลส่วนบุคคลของคุณ',
    'account_deletion.before.title': 'ก่อนส่งคำขอ',
    'account_deletion.before.body':
        'เมื่อคำขอได้รับการตรวจสอบ บัญชีจะไม่สามารถเข้าสู่ระบบได้อีก และข้อมูลธุรกรรมบางส่วนอาจต้องถูกเก็บไว้ตามกฎหมาย',
    'account_deletion.request.title': 'ช่องทางส่งคำขอ',
    'account_deletion.request.body':
        'คุณสามารถเริ่มคำขอลบบัญชีผ่านช่องทางที่ร้านค้ากำหนด ระบบจะใช้ข้อมูลบัญชีปัจจุบันเพื่อยืนยันตัวตนก่อนดำเนินการ',
    'account_deletion.open_request': 'ส่งคำขอลบบัญชี',
    'account_deletion.contact_support': 'ติดต่อร้านค้า',
    'account_deletion.contact_support_online': 'ติดต่อร้านค้าผ่านเว็บไซต์',
    'account_deletion.contact_support_with_phone': 'ติดต่อร้านค้า {phone}',
    'account_deletion.contact_support_with_email': 'ติดต่อร้านค้า {email}',
    'account_deletion.no_online_request':
        'ร้านค้านี้ยังไม่ได้ตั้งค่าลิงก์คำขอลบบัญชี กรุณาติดต่อร้านค้าเพื่อดำเนินการ',
    'account_deletion.launch_failed': 'เปิดลิงก์คำขอไม่สำเร็จ',
    'wallet.title': 'กระเป๋าของฉัน',
    'wallet.balance.loading': 'กำลังโหลด...',
    'wallet.recent_ledger': 'ประวัติรายการเดินเงินล่าสุด',
    'wallet.recent_ledger.subtitle': 'รายการเติมเงิน ชำระเงิน และรับเงินรางวัล',
    'wallet.refresh_tooltip': 'โหลดรายการใหม่',
    'wallet.ledger.loading': 'กำลังโหลดรายการ...',
    'wallet.ledger.load_failed': 'โหลดประวัติไม่สำเร็จ',
    'wallet.ledger.load_failed_message': 'กรุณาลองใหม่อีกครั้ง',
    'wallet.empty_ledger.title': 'ยังไม่มีรายการเดินเงิน',
    'wallet.empty_ledger.subtitle':
        'รายการเติมเงิน ชำระเงิน และรับเงินรางวัลจะแสดงที่นี่',
    'wallet.balance_after': 'คงเหลือ {amount}',
    'wallet.ledger.topup': 'เติมเงินเข้า G-Wallet',
    'wallet.ledger.order': 'ชำระค่าสลากดิจิทัล',
    'wallet.ledger.reward_claim': 'รับเงินรางวัลสลากฯ',
    'wallet.ledger.activity_reward': 'รางวัลกิจกรรม',
    'wallet.ledger.activity_cashback': 'เงินคืนกิจกรรม',
    'wallet.ledger.order_refund': 'คืนเงินเข้ากระเป๋า',
    'wallet.ledger.debit': 'เงินออกจากกระเป๋า',
    'wallet.ledger.credit': 'เงินเข้ากระเป๋า',
    'wallet.ledger.generic': 'รายการกระเป๋า',
    'wallet.ledger.reference': 'อ้างอิง {reference}',
    'wallet.ledger.success': 'รายการสำเร็จ',
    'topup.title': 'เติมเงินเข้า G-Wallet',
    'topup.loading': 'กำลังโหลดช่องทางเติมเงิน',
    'topup.loading_message': 'กรุณารอสักครู่ ระบบกำลังเตรียมข้อมูลการเติมเงิน',
    'topup.load_failed': 'โหลดข้อมูลเติมเงินไม่สำเร็จ',
    'topup.load_failed_message': 'กรุณาลองใหม่อีกครั้ง',
    'topup.header.title': 'เติมเงินเข้า G-Wallet',
    'topup.header.subtitle': 'เลือกช่องทางและสร้างรายการเติมเงิน',
    'topup.history_tooltip': 'ดูประวัติเติมเงิน',
    'topup.waiting.title': 'รายการเติมเงินที่ยังไม่เสร็จ',
    'topup.waiting.amount_label': 'ยอดเติมเงิน',
    'topup.waiting.qr_title': 'สแกน QR Code เพื่อชำระเงิน',
    'topup.waiting.slip_title': 'สลิปชำระเงิน',
    'topup.waiting.slip_pending': 'รอสลิป',
    'topup.waiting.slip_sent': 'ส่งแล้ว',
    'topup.waiting.slip_pending_description':
        'อัพโหลดสลิปหลังจากชำระเงินรายการนี้',
    'topup.waiting.slip_sent_description':
        'ได้รับสลิปแล้ว สามารถอัพโหลดใหม่ได้หากต้องแก้ไข',
    'topup.reference': 'รายการ #{reference}',
    'topup.qr_slip_instruction':
        'หลังชำระเงินแล้วแนบสลิปเพื่อให้ร้านค้าตรวจสอบ',
    'topup.open_payment': 'เปิดหน้าชำระเงิน',
    'topup.open_payment_failed': 'เปิดหน้าชำระเงินไม่สำเร็จ',
    'topup.needs_slip': 'รายการนี้รอสลิปหรือรอทีมงานตรวจสอบ',
    'topup.upload_slip': 'แนบสลิปชำระเงิน',
    'topup.upload_new_slip': 'อัพโหลดสลิปใหม่',
    'topup.uploading_slip': 'กำลังอัพโหลด...',
    'topup.cancel_waiting': 'ยกเลิกรายการเติมเงินนี้',
    'topup.cancel_confirm.title': 'ยกเลิกรายการเติมเงินนี้?',
    'topup.cancel_confirm.message':
        'รายการ #{reference} จะถูกยกเลิก และคุณสามารถสร้างรายการเติมเงินใหม่ได้ทันที',
    'topup.cancel_confirm.amount_label': 'ยอดเติมเงิน',
    'topup.cancel_confirm.keep': 'ไม่ยกเลิก',
    'topup.cancel_confirm.confirm': 'ยืนยันยกเลิก',
    'topup.cancel_confirm.cancelling': 'กำลังยกเลิก...',
    'topup.choose_channel': 'เลือกช่องทางการเติมเงิน',
    'topup.blocking_waiting.title': 'มีรายการเติมเงินค้างอยู่',
    'topup.blocking_waiting.message':
        'กรุณาชำระหรือยกเลิกรายการเดิมก่อนสร้างรายการใหม่',
    'topup.amount_label': 'จำนวนเงินที่ต้องการเติม',
    'topup.baht_suffix': 'บาท',
    'topup.submit.qr': 'สร้าง QR Code',
    'topup.submit.credit_qr': 'สร้าง QR Code',
    'topup.submit.bank_transfer': 'ยืนยันการชำระเงิน',
    'topup.submit.creating_qr': 'กำลังสร้าง QR...',
    'topup.submit.submitting_bank_transfer': 'กำลังส่งสลิป...',
    'topup.bank_slip.title': 'สลิปโอนเงิน',
    'topup.bank_slip.description':
        'แนบรูปสลิปและส่งให้แอดมินตรวจสอบพร้อมรายการเติมเงิน',
    'topup.bank_slip.attach': 'แนบสลิป',
    'topup.bank_slip.change': 'เปลี่ยนสลิป',
    'topup.bank_slip.remove': 'ลบสลิป',
    'topup.bank_slip.file_label': 'ไฟล์สลิป',
    'topup.bank_slip.transfer_at': 'วันเวลาที่โอน',
    'topup.bank_slip.transfer_at_unset': 'เลือกวันเวลาที่โอน',
    'topup.bank_slip.required': 'กรุณาแนบรูปสลิปก่อนส่งให้แอดมินตรวจสอบ',
    'topup.bank_transfer_submitted':
        'ส่งสลิปสำเร็จ กรุณารอแอดมินตรวจสอบสักครู่',
    'topup.deferred_slip.qr':
        'สร้าง QR Code แล้วแนบสลิปหลังชำระเงินเพื่อให้ร้านค้าตรวจสอบ',
    'topup.deferred_slip.credit':
        'ช่องทางนี้จะแสดงเป็น QR Code และแนบสลิปหลังชำระเงินได้',
    'topup.channel.qr.label': 'QR Code',
    'topup.channel.qr.description': 'สร้าง QR Code แล้วแนบสลิปหลังชำระเงิน',
    'topup.channel.credit.label': 'Credit Card QR',
    'topup.channel.credit.description':
        'สร้าง QR Code สำหรับชำระผ่านช่องทางเครดิต',
    'topup.channel.bank.label': 'โอนธนาคาร',
    'topup.channel.bank.description': 'โอนเข้าบัญชีร้านค้าแล้วแนบสลิปภายหลัง',
    'topup.channel.disabled': 'ปิดบริการชั่วคราว',
    'topup.bank_account_fallback': 'บัญชีรับโอน',
    'topup.status.pending_payment': 'รอชำระ',
    'topup.status.pending_review': 'รอตรวจสอบ',
    'topup.status.approved': 'อนุมัติแล้ว',
    'topup.status.rejected': 'ไม่อนุมัติ',
    'topup.status.cancelled': 'ยกเลิกแล้ว',
    'topup.status.expired': 'หมดอายุ',
    'topup.status.unknown': 'กำลังดำเนินการ',
    'topup.error.amount_required': 'กรุณากรอกจำนวนเงินที่ต้องการเติม',
    'topup.error.minimum_amount': '{channel} ขั้นต่ำ {amount}',
    'topup.minimum_hint': 'เติมขั้นต่ำ {amount}',
    'topup.created': 'สร้างรายการเติมเงินแล้ว',
    'topup.create_failed': 'สร้างรายการเติมเงินไม่สำเร็จ กรุณาลองใหม่',
    'topup.cancelled': 'ยกเลิกรายการเติมเงินแล้ว',
    'topup.cancel_failed': 'ยกเลิกรายการไม่สำเร็จ',
    'topup.slip_too_large': 'ไฟล์สลิปต้องไม่เกิน 5 MB',
    'topup.slip_uploaded': 'อัพโหลดสลิปสำเร็จ',
    'topup.slip_upload_failed': 'อัพโหลดสลิปไม่สำเร็จ กรุณาลองใหม่',
    'topup.history.title': 'ประวัติเติมเงิน',
    'topup.history.loading': 'กำลังโหลดข้อมูล...',
    'topup.history.load_failed': 'โหลดประวัติไม่สำเร็จ',
    'topup.history.header.title': 'รายการเติมเงินล่าสุด',
    'topup.history.header.subtitle': 'ตรวจสอบสถานะรายการเติมเงินเข้า G-Wallet',
    'topup.history.item_title': 'เติมเงินเข้า G-Wallet',
    'topup.history.reference': 'รายการ #{reference}\n{channel} • {date}',
    'topup.history.bonus': 'โบนัส {amount}',
    'topup.history.empty.title': 'ยังไม่มีประวัติเติมเงิน',
    'topup.history.empty.subtitle':
        'เมื่อเติมเงินสำเร็จ รายการจะแสดงที่หน้านี้',
    'reward_claims.title': 'ประวัติขึ้นเงินรางวัล',
    'reward_claims.header.title': 'ประวัติขึ้นเงินรางวัลสลากดิจิทัล',
    'reward_claims.header.subtitle': 'ตรวจสอบสถานะรายการขึ้นเงินรางวัล',
    'reward_claims.tickets_tooltip': 'ดูสลากฯ',
    'reward_claims.prize_title': 'เงินรางวัลสลากฯ',
    'reward_claims.loading': 'กำลังโหลดประวัติขึ้นเงิน...',
    'reward_claims.load_failed': 'โหลดประวัติขึ้นเงินไม่สำเร็จ',
    'reward_claims.load_more_failed': 'โหลดรายการเพิ่มเติมไม่สำเร็จ',
    'reward_claims.loading_more': 'กำลังโหลด...',
    'reward_claims.load_more': 'โหลดเพิ่มเติม',
    'reward_claims.empty.title': 'ยังไม่มีประวัติขึ้นเงิน',
    'reward_claims.empty.subtitle':
        'เมื่อส่งรายการขึ้นเงินรางวัลแล้ว รายการจะแสดงที่หน้านี้',
    'reward_claims.view_winning_tickets': 'ดูสลากฯ ที่ถูกรางวัล',
    'reward_claims.detail.title': 'รายละเอียดการขึ้นเงินรางวัล',
    'reward_claims.detail.loading': 'กำลังโหลดรายการขึ้นเงิน...',
    'reward_claims.detail.load_failed': 'โหลดรายการขึ้นเงินไม่สำเร็จ',
    'reward_claims.detail.method': 'วิธีขึ้นเงินรางวัล',
    'reward_claims.detail.manual_method': 'ขึ้นเงินรางวัลด้วยตนเอง',
    'reward_claims.detail.payout_channel': 'ช่องทางขึ้นเงินรางวัล',
    'reward_claims.detail.status': 'สถานะ',
    'reward_claims.detail.draw_date': 'สลากฯ งวดวันที่',
    'reward_claims.detail.tax': 'ค่าภาษีถอนเงิน (0.5%)',
    'reward_claims.detail.fee': 'ค่าธรรมเนียม (1%)',
    'reward_claims.detail.waived': 'ลดให้ {amount}',
    'reward_claims.detail.zero_baht': '0 บาท',
    'reward_claims.detail.bank_fallback': 'บัญชีธนาคาร',
    'reward_claims.detail.wallet_fallback': 'G-Wallet',
    'reward_claims.customer_fallback': 'ผู้ใช้งาน',
    'reward_claims.payout.bank_prefix': 'ธนาคาร',
    'reward_claims.payout.bank': 'รับผ่านบัญชี{bank}',
    'reward_claims.payout.wallet': 'รับเข้า {wallet}',
    'reward_claims.prize.more': '{prize} และอีก {count} รางวัล',
    'reward_claims.prize.first_prize': 'รางวัลที่ 1',
    'reward_claims.prize.near_first_prize': 'รางวัลข้างเคียงรางวัลที่ 1',
    'reward_claims.prize.second_prize': 'รางวัลที่ 2',
    'reward_claims.prize.third_prize': 'รางวัลที่ 3',
    'reward_claims.prize.fourth_prize': 'รางวัลที่ 4',
    'reward_claims.prize.fifth_prize': 'รางวัลที่ 5',
    'reward_claims.prize.front3': 'รางวัลเลขหน้า 3 ตัว',
    'reward_claims.prize.back3': 'รางวัลเลขท้าย 3 ตัว',
    'reward_claims.prize.back2': 'รางวัลเลขท้าย 2 ตัว',
    'reward_claims.prize.fallback': 'ถูกรางวัล',
    'reward_claims.status.paid': 'โอนเงินสำเร็จ',
    'reward_claims.status.rejected': 'ขึ้นเงินไม่สำเร็จ',
    'reward_claims.status.cancelled': 'ยกเลิกรายการ',
    'reward_claims.status.approved': 'อนุมัติแล้ว รอโอนเงิน',
    'reward_claims.status.submitted': 'รอดำเนินการโอนเงิน',
    'reward_claims.note.paid': 'โอนเงินรางวัลเข้าบัญชีผู้รับเงินเรียบร้อยแล้ว',
    'reward_claims.note.rejected':
        'รายการขึ้นเงินไม่สำเร็จ กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ',
    'reward_claims.note.cancelled':
        'รายการขึ้นเงินถูกยกเลิก กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ',
    'reward_claims.note.approved':
        'รายการได้รับอนุมัติแล้ว กำลังดำเนินการโอนเงินรางวัล',
    'reward_claims.note.submitted':
        'เงินรางวัลจะเข้าบัญชีผู้รับเงินภายใน 2 ชั่วโมง หลังจากทำรายการสำเร็จ',
    'reward_claims.detail.empty': 'ไม่พบรายการขึ้นเงินรางวัล',
    'activity_claims.title': 'ประวัติขึ้นเงินรางวัลกิจกรรม',
    'activity_claims.header.title': 'ประวัติรับเงินรางวัลกิจกรรม',
    'activity_claims.header.subtitle': 'ตรวจสอบสถานะเงินคืนและรางวัลกิจกรรม',
    'activity_claims.activities_tooltip': 'ดูกิจกรรม',
    'activity_claims.prize_title': 'เงินรางวัลกิจกรรม',
    'activity_claims.loading': 'กำลังโหลดประวัติขึ้นเงินกิจกรรม...',
    'activity_claims.load_failed': 'โหลดประวัติขึ้นเงินกิจกรรมไม่สำเร็จ',
    'activity_claims.load_more_failed': 'โหลดรายการเพิ่มเติมไม่สำเร็จ',
    'activity_claims.empty.title': 'ยังไม่มีประวัติขึ้นเงินกิจกรรม',
    'activity_claims.empty.subtitle':
        'เมื่อรับเงินรางวัลหรือเงินคืนจากกิจกรรม รายการจะแสดงที่หน้านี้',
    'activity_claims.view_activities': 'ดูกิจกรรม',
    'activity_claims.detail.title': 'รายละเอียดขึ้นเงินรางวัลกิจกรรม',
    'activity_claims.detail.loading': 'กำลังโหลดรายการขึ้นเงินกิจกรรม...',
    'activity_claims.detail.load_failed': 'โหลดรายการขึ้นเงินกิจกรรมไม่สำเร็จ',
    'activity_claims.detail.reward_title': 'รางวัลกิจกรรม',
    'activity_claims.activity_fallback': 'กิจกรรม',
    'activity_claims.customer_fallback': 'ผู้ใช้งาน',
    'activity_claims.detail.recipient': 'ผู้รับเงิน',
    'activity_claims.detail.payout_channel': 'ช่องทางขึ้นเงินรางวัล',
    'activity_claims.detail.payout_method': 'วิธีขึ้นเงินรางวัล',
    'activity_claims.detail.status': 'สถานะ',
    'activity_claims.detail.activity': 'กิจกรรม',
    'activity_claims.detail.reward_type': 'ประเภทรางวัล',
    'activity_claims.detail.reference': 'รหัสรายการ',
    'activity_claims.detail.submitted_at': 'วันที่ทำรายการ',
    'activity_claims.detail.paid_at': 'วันที่โอนเงิน',
    'activity_claims.detail.reviewed_at': 'วันที่ตรวจสอบ',
    'activity_claims.detail.customer_note': 'หมายเหตุของลูกค้า',
    'activity_claims.detail.admin_note': 'หมายเหตุจากผู้ตรวจสอบ',
    'activity_claims.payout.bank_transfer': 'โอนเข้าบัญชีธนาคาร',
    'activity_claims.payout.wallet_credit': 'รับเข้า G-Wallet',
    'activity_claims.payout.bank_fallback': 'บัญชีธนาคาร',
    'activity_claims.payout.wallet_fallback': 'G-Wallet',
    'activity_claims.payout.bank_prefix': 'ธนาคาร',
    'activity_claims.payout.bank_summary': 'รับผ่านบัญชี{bank}',
    'activity_claims.payout.wallet_summary': 'รับเข้า {wallet}',
    'activity_claims.detail.amount': 'ยอดรางวัลกิจกรรม',
    'activity_claims.detail.net_amount': 'ยอดเงินที่ได้รับ',
    'activity_claims.detail.empty': 'ไม่พบรายการขึ้นเงินกิจกรรมนี้',
    'activity_claims.status.paid': 'โอนเงินสำเร็จ',
    'activity_claims.status.rejected': 'ขึ้นเงินไม่สำเร็จ',
    'activity_claims.status.cancelled': 'ยกเลิกรายการ',
    'activity_claims.status.approved': 'อนุมัติแล้ว รอโอนเงิน',
    'activity_claims.status.submitted': 'รอดำเนินการโอนเงิน',
    'activity_claims.note.paid': 'โอนเงินรางวัลกิจกรรมเรียบร้อยแล้ว',
    'activity_claims.note.rejected':
        'รายการขึ้นเงินกิจกรรมไม่สำเร็จ กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ',
    'activity_claims.note.cancelled':
        'รายการขึ้นเงินกิจกรรมถูกยกเลิก กรุณาตรวจสอบรายละเอียดหรือติดต่อผู้ให้บริการ',
    'activity_claims.note.approved':
        'รายการได้รับอนุมัติแล้ว กำลังดำเนินการโอนเงินรางวัลกิจกรรม',
    'activity_claims.note.submitted':
        '{reviewer} จะตรวจสอบและดำเนินการจ่ายเงินรางวัลกิจกรรมให้คุณ',
    'activity_claims.reviewer_fallback': 'ผู้ให้บริการ',
    'activity_claims.reward.cashback': 'เงินคืนกิจกรรม',
    'activity_claims.reward.first_prize_last2':
        'รางวัลแผงเลขนำโชค 2 ตัวท้ายรางวัลที่ 1',
    'activity_claims.reward.first_prize_last3':
        'รางวัลแผงเลขนำโชค 3 ตัวท้ายรางวัลที่ 1',
    'activity_claims.reward.last2': 'รางวัลแผงเลขนำโชคเลขท้าย 2 ตัว',
    'activity_claims.reward.fallback': 'รางวัลกิจกรรม',
    'activities.history_button': 'ดูงวดที่แล้ว',
    'activities.history_title': 'กิจกรรมงวดย้อนหลัง',
    'activities.history_hint': 'ดูรายการกิจกรรมของงวดก่อนหน้า',
    'activities.history_select_label': 'เลือกงวดย้อนหลัง',
    'activities.history_no_games': 'ไม่มีกิจกรรมย้อนหลัง',
    'activities.back_to_current': 'กลับไปกิจกรรมงวดปัจจุบัน',
    'activities.loading': 'กำลังโหลดกิจกรรม',
    'activities.history_loading': 'กำลังโหลดกิจกรรมย้อนหลัง',
    'activities.load_failed': 'โหลดกิจกรรมไม่สำเร็จ',
    'activities.empty.title': 'ยังไม่มีกิจกรรมในงวดนี้',
    'activities.empty.message':
        'เมื่อร้านค้าจัดกิจกรรมสำหรับงวดปัจจุบัน คุณจะเห็นรายละเอียดได้ที่หน้านี้',
    'activities.history_empty.title': 'ยังไม่มีกิจกรรมย้อนหลัง',
    'activities.history_empty.message':
        'เมื่อมีรายการกิจกรรมของงวดก่อนหน้า คุณจะเลือกดูย้อนหลังได้จากหน้านี้',
    'activities.fallback_name': 'กิจกรรมพิเศษ',
    'activities.type.cashback': 'รับเงินคืน',
    'activities.type.lucky_board': 'แผงเลขนำโชค',
    'activities.prediction.first_prize_last2': '2 ตัวท้ายรางวัลที่ 1',
    'activities.prediction.first_prize_last3': '3 ตัวท้ายรางวัลที่ 1',
    'activities.prediction.last2': 'เลขท้าย 2 ตัว',
    'activities.prediction.fallback': 'แผงเลขนำโชค',
    'activities.condition.fallback': 'ดูรายละเอียดกิจกรรมและเงื่อนไข',
    'activities.condition.min_tickets':
        'ซื้อครบ {count} ใบ เพื่อรับสิทธิ์เข้าร่วม',
    'activities.condition.min_baht': 'ซื้อครบ {amount} เพื่อรับสิทธิ์',
    'activities.meta.cashback_estimate': 'คาดว่าจะได้รับ {amount}',
    'activities.meta.cashback_pending': 'ตรวจสิทธิ์เงินคืนหลังออกผล',
    'activities.meta.entry_closed': 'หมดเวลาเข้าร่วมแล้ว',
    'activities.meta.guest': 'เข้าสู่ระบบเพื่อเช็คสิทธิ์',
    'activities.meta.pin': 'ยืนยัน PIN เพื่อเช็คสิทธิ์',
    'activities.meta.rights_used': 'มีสิทธิ์ 0 สิทธิ์ (ใช้ครบแล้ว)',
    'activities.meta.no_rights': 'ยังไม่มีสิทธิ์ (0 สิทธิ์)',
    'activities.meta.deadline': 'ร่วมได้ถึง {date}',
    'activities.meta.deadline_fallback': 'ปิดรับหลังปิดขาย 30 นาที',
    'activities.meta.rights': 'มีสิทธิ์ {count} สิทธิ์',
    'activities.meta.remaining_numbers': 'เหลือ {count} เลขให้เลือก',
    'activity_detail.title': 'รายละเอียดกิจกรรม',
    'activity_detail.loading': 'กำลังโหลดรายละเอียดกิจกรรม...',
    'activity_detail.load_failed': 'โหลดรายละเอียดกิจกรรมไม่สำเร็จ',
    'activity_detail.has_right': 'มีสิทธิ์เข้าร่วม',
    'activity_detail.entry_closed': 'หมดเวลาเข้าร่วม',
    'activity_detail.game_fallback': 'งวดกิจกรรม',
    'activity_detail.result_time': 'ออกผลกิจกรรม {time}',
    'activity_detail.confirm_number.eyebrow': 'ยืนยันเลขนำโชค',
    'activity_detail.confirm_number.title': 'ต้องการเลือกเลขนี้ใช่ไหม?',
    'activity_detail.confirm_number.message':
        'ระบบจะใช้ 1 สิทธิ์ของคุณสำหรับ {prediction} และไม่สามารถเลือกเลขนี้ซ้ำได้',
    'activity_detail.confirm_number.submit': 'ยืนยันเลือกเลข',
    'activity_detail.entry.submit_success': 'ส่งเลขสำเร็จ',
    'activity_detail.entry.closed': 'กิจกรรมนี้หมดเวลาเข้าร่วมแล้ว',
    'activity_detail.entry.submit_failed':
        'ส่งเลขไม่สำเร็จ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่',
    'activity_detail.status.cashback_title': 'สิทธิ์รับเงินคืน',
    'activity_detail.status.number_title': 'เลขที่เหลือให้เลือก',
    'activity_detail.status.calculating': 'รอคำนวณ',
    'activity_detail.status.remaining_numbers': '{count} เลข',
    'activity_detail.status.cashback_subtitle':
        'ระบบจะตรวจสิทธิ์หลังออกผลตามเงื่อนไขของกิจกรรม',
    'activity_detail.status.board_closed': 'กิจกรรมนี้ปิดรับเลขแล้ว',
    'activity_detail.status.board_available':
        'เลือกเลขได้ตามจำนวนสิทธิ์ที่ได้รับจากยอดซื้อในงวดนี้',
    'activity_detail.cashback.title': 'สิทธิ์รับเงินคืน',
    'activity_detail.cashback.progress_eligible': 'เข้าเงื่อนไขยอดซื้อ',
    'activity_detail.cashback.progress_pending': 'รอเข้าเงื่อนไข',
    'activity_detail.cashback.eligible_title': 'ยอดซื้อเข้าเงื่อนไขแล้ว',
    'activity_detail.cashback.pending_title': 'ยังไม่เข้าเงื่อนไขยอดซื้อ',
    'activity_detail.cashback.eligible_description':
        'ระบบจะตรวจสิทธิ์เวลา {resultTime} โดยลูกค้าต้องไม่ถูกรางวัลสลากและไม่ถูกรางวัลแผงเลขนำโชค',
    'activity_detail.cashback.pending_description':
        'ซื้อให้ครบ {minimum} ในงวดนี้ เพื่อรอคำนวณเงินคืนเวลา {resultTime}',
    'activity_detail.cashback.reward_fallback': 'รับเงินคืนตามเงื่อนไขกิจกรรม',
    'activity_detail.cashback.expected_label': 'ยอดที่คุณควรได้รับ',
    'activity_detail.cashback.expected_hint':
        'ระบบจะสรุปสิทธิ์อีกครั้งเวลา {resultTime}',
    'activity_detail.cashback.purchase_amount': 'ยอดซื้อในงวด',
    'activity_detail.cashback.ticket_count': 'จำนวนสลาก',
    'activity_detail.cashback.minimum': 'เงื่อนไขขั้นต่ำ',
    'activity_detail.cashback.no_minimum': 'ไม่มีขั้นต่ำ',
    'activity_detail.cashback.tickets': '{count} ใบ',
    'activity_detail.cashback.detail.reward_type': 'รูปแบบเงินคืน',
    'activity_detail.cashback.detail.main_condition': 'เงื่อนไขหลัก',
    'activity_detail.cashback.detail.main_condition_value':
        'ไม่ถูกรางวัลสลาก และไม่ถูกรางวัลแผงเลขนำโชค',
    'activity_detail.cashback.detail.calculation_time': 'เวลาคำนวณ',
    'activity_detail.cashback.detail.payout': 'การรับเงิน',
    'activity_detail.cashback.detail.payout_value':
        'เลือกรับเองจากรางวัลกิจกรรม หรือเปิดรับอัตโนมัติ',
    'activity_detail.cashback.manual_claim.title': 'รับเงินเอง',
    'activity_detail.cashback.manual_claim.ready': 'มีเงินคืนพร้อมรับแล้ว',
    'activity_detail.cashback.manual_claim.pending':
        'เมื่อระบบคำนวณแล้วจะมีปุ่มรับเงิน',
    'activity_detail.cashback.auto_reward.title': 'รับอัตโนมัติ',
    'activity_detail.cashback.auto_reward.subtitle':
        'ตั้งค่าช่องทางรับเงินอัตโนมัติ',
    'activity_detail.cashback.claim_not_ready.title': 'ยังไม่มีเงินคืนพร้อมรับ',
    'activity_detail.cashback.claim_not_ready.message':
        'ระบบจะแสดงรายการเงินคืนหลังคำนวณสิทธิ์เรียบร้อยแล้ว',
    'activity_detail.cashback.result_time_fallback': '17:00 น. ของวันที่ออกผล',
    'activity_detail.result.title': 'ผลกิจกรรม',
    'activity_detail.result.winning_number': 'หมายเลขที่ชนะ {prediction}',
    'activity_detail.result.customer_won': 'คุณถูกรางวัลกิจกรรม {amount}',
    'activity_detail.result.customer_lost': 'คุณไม่ถูกรางวัลกิจกรรมนี้',
    'activity_detail.result.customer_winning_numbers': 'เลขของคุณที่ถูกรางวัล',
    'activity_detail.result.winner_count': 'มีผู้ชนะ {count} ราย',
    'activity_detail.award.claim_button': 'รับเงิน',
    'activity_detail.award.ready': 'พร้อมรับเงินรางวัล',
    'activity_detail.award.claimed': 'ส่งคำขอรับเงินแล้ว',
    'activity_detail.award.processing': 'ระบบกำลังดำเนินการ',
    'activity_detail.award_status.title': 'รางวัลกิจกรรม',
    'activity_detail.award_status.count': '{count} รายการ',
    'activity_detail.award_status.login_count': 'เข้าสู่ระบบเพื่อดูสถานะ',
    'activity_detail.award_status.not_joined_count': 'ไม่ได้เข้าร่วม',
    'activity_detail.award_status.no_reward_count': 'ยังไม่มีรางวัล',
    'activity_detail.award_status.pending_count': 'รอออกผล',
    'activity_detail.award_status.missed_title': 'คุณไม่ได้รับรางวัลกิจกรรมนี้',
    'activity_detail.award_status.not_joined_title':
        'คุณยังไม่ได้เข้าร่วมกิจกรรมนี้',
    'activity_detail.award_status.pending_title': 'รอออกผลกิจกรรม',
    'activity_detail.award_status.login_title':
        'เข้าสู่ระบบเพื่อดูรางวัลของคุณ',
    'activity_detail.award_status.no_reward_title':
        'ยังไม่มีรางวัลกิจกรรมของคุณ',
    'activity_detail.award_status.missed_message':
        'เลขที่คุณเลือกไม่ตรงกับหมายเลขที่ชนะของกิจกรรมนี้',
    'activity_detail.award_status.not_joined_message':
        'ใช้สิทธิ์เลือกเลขก่อนออกผล เพื่อร่วมลุ้นรางวัลกิจกรรม',
    'activity_detail.award_status.pending_message':
        'ระบบจะสรุปผลและแสดงรางวัลหลังประกาศผลกิจกรรม',
    'activity_detail.award_status.login_message':
        'เข้าสู่ระบบเพื่อดูว่าคุณได้รับรางวัลหรือเงินคืนจากกิจกรรมนี้หรือไม่',
    'activity_detail.award_status.no_reward_message':
        'ระบบประกาศผลแล้ว แต่ยังไม่มีรางวัลที่รับได้สำหรับกิจกรรมนี้',
    'activity_detail.condition.title': 'เงื่อนไขกิจกรรม',
    'activity_detail.rights.title': 'สิทธิ์ของคุณ',
    'activity_detail.rights.earned': 'ได้รับ',
    'activity_detail.rights.used': 'ใช้แล้ว',
    'activity_detail.rights.remaining': 'คงเหลือ',
    'activity_detail.rights.ticket_summary':
        'ซื้อสะสม {total} ใบ · ใช้คำนวณไปแล้ว {consumed} ใบ',
    'activity_detail.rights.deadline': 'หมดเวลาเข้าร่วม {date}',
    'activity_detail.selected_numbers.title': 'เลขที่เลือกแล้ว',
    'activity_detail.board.title': 'แผงเลข {prediction}',
    'activity_detail.board.summary':
        '{range} · เหลือ {remaining} จาก {total} เลข',
    'activity_detail.board.can_select':
        'แตะเลขเพื่อยืนยันการเลือก ใช้ 1 สิทธิ์ต่อ 1 เลข',
    'activity_detail.board.closed': 'กิจกรรมนี้หมดเวลาเข้าร่วมแล้ว',
    'activity_detail.board.no_rights': 'ยังไม่มีสิทธิ์คงเหลือสำหรับเลือกเลข',
    'activity_detail.board.reserved_hint': 'เลขสีแดงถูกเลือกแล้ว',
    'activity_detail.board.reserved_short': 'จอง',
    'activity_detail.board.entry_closed_hint': 'หมดเวลาเข้าร่วม',
    'activity_detail.login_to_join.title':
        'เข้าสู่ระบบเพื่อดูสิทธิ์และเลือกเลข',
    'activity_detail.login_to_join.button': 'เข้าสู่ระบบ',
    'activity_detail.claim_sheet.title': 'รับเงินรางวัลกิจกรรม',
    'activity_detail.claim_sheet.eyebrow': 'รับเงินกิจกรรม',
    'activity_detail.claim_sheet.available_amount': 'ยอดที่รับได้',
    'activity_detail.claim_sheet.wallet.title': 'รับเข้า G-Wallet',
    'activity_detail.claim_sheet.wallet.account_title': 'G Wallet x {suffix}',
    'activity_detail.claim_sheet.wallet.subtitle':
        'เงินเข้ากระเป๋าในระบบหลัง {reviewer} อนุมัติ',
    'activity_detail.claim_sheet.bank.title': 'โอนเข้าบัญชีธนาคาร',
    'activity_detail.claim_sheet.bank.ready':
        'รับเงินเข้าบัญชีรับเงินรางวัลที่บันทึกไว้',
    'activity_detail.claim_sheet.bank.missing': 'ยังไม่ได้ตั้งค่าบัญชีรับเงิน',
    'activity_detail.claim_sheet.bank.recipient_fallback': 'ผู้รับเงิน',
    'activity_detail.claim_sheet.setup_bank': 'ตั้งค่าบัญชีรับเงิน',
    'activity_detail.claim_sheet.confirm_pin': 'ยืนยันด้วย PIN',
    'activity_detail.claim_sheet.pin.title': 'ใส่รหัส PIN 6 หลัก',
    'activity_detail.claim_sheet.pin.subtitle': 'เพื่อรับเงินรางวัลกิจกรรม',
    'activity_detail.claim_sheet.pin.progress': 'กรอกแล้ว {count}/6 หลัก',
    'activity_detail.claim_sheet.profile_loading': 'กำลังโหลดข้อมูลรับเงิน...',
    'activity_detail.claim_sheet.profile_load_failed':
        'โหลดข้อมูลรับเงินไม่สำเร็จ กรุณาลองใหม่',
    'activity_detail.claim_sheet.bank_required': 'กรุณาตั้งค่าบัญชีรับเงินก่อน',
    'activity_detail.claim_sheet.pin_invalid': 'PIN ไม่ถูกต้อง กรุณาลองใหม่',
    'activity_detail.claim_sheet.pin_locked':
        'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่',
    'activity_detail.claim_sheet.pin_setup_required':
        'กรุณาตั้งค่า PIN ก่อนทำรายการ',
    'activity_detail.claim_sheet.submit_failed':
        'รับเงินกิจกรรมไม่สำเร็จ กรุณาลองใหม่',
    'activity_detail.claim_sheet.biometric_unavailable':
        'ไม่สามารถยืนยันด้วยชีวมิติได้',
    'activity_detail.claim_sheet.biometric_failed':
        'ยืนยันด้วยชีวมิติไม่สำเร็จ กรุณาใช้ PIN',
    'activity_detail.claim_sheet.biometric_button': 'ใช้ Face ID / Biometric',
    'activity_detail.missing': 'ไม่พบกิจกรรมนี้',
    'activity_detail.missing.title': 'ไม่พบกิจกรรม',
    'activity_detail.missing.message':
        'กิจกรรมนี้อาจถูกปิดใช้งานหรือหมดช่วงแสดงผลแล้ว',
    'activity_detail.missing.back_to_activities': 'กลับหน้ากิจกรรม',
    'purchase_history.title': 'ประวัติการซื้อสลากฯ',
    'purchase_history.header.title': 'รายการซื้อสลากหกหลักแบบดิจิทัล',
    'purchase_history.header.subtitle': 'ดูรายการซื้อย้อนหลังและใบเสร็จ',
    'purchase_history.buy_tooltip': 'ซื้อสลากฯ',
    'purchase_history.year': 'ปี {year}',
    'purchase_history.order_title': 'ซื้อสลากฯ',
    'purchase_history.digital_ticket': 'สลากดิจิทัล',
    'purchase_history.draw_date': 'งวดวันที่ {date}',
    'purchase_history.ticket_count': '{count} ใบ',
    'purchase_history.load_failed': 'โหลดประวัติการซื้อไม่สำเร็จ',
    'purchase_history.load_more_failed': 'โหลดรายการเพิ่มเติมไม่สำเร็จ',
    'purchase_history.empty.title': 'ยังไม่มีประวัติการซื้อสลากฯ',
    'purchase_history.empty.subtitle':
        'เมื่อซื้อสลากสำเร็จ รายการจะแสดงที่หน้านี้',
    'purchase_history.buy_button': 'ซื้อสลากฯ',
    'purchase_history.detail.title': 'รายละเอียดการซื้อสลากฯ',
    'purchase_history.detail.receipt_title': 'รายการซื้อสลากหกหลักแบบดิจิทัล',
    'purchase_history.detail.receipt_subtitle':
        'คุณสามารถดูสลากฯ ได้ที่เมนู สลากฯ ของฉัน',
    'purchase_history.detail.ticket_count': 'จำนวนสลากฯ',
    'purchase_history.detail.draw_date': 'สลากฯ งวดวันที่',
    'purchase_history.detail.payee': 'ชำระเงินให้',
    'purchase_history.detail.payment_channel': 'ช่องทางชำระเงิน',
    'purchase_history.detail.total': 'ยอดชำระทั้งหมด',
    'purchase_history.detail.transaction_at': 'วันที่ทำรายการ {date}',
    'purchase_history.detail.reference': 'รหัสอ้างอิง {reference}',
    'purchase_history.detail.reference_label': 'รหัสอ้างอิง',
    'purchase_history.detail.ticket_list': 'เลขสลากในรายการ',
    'purchase_history.detail.empty': 'ไม่พบรายการซื้อสลากฯ นี้',
    'purchase_history.store_fallback': 'ร้านค้าสลากฯ',
    'lottery.tabs.all': 'สลากฯ ทั้งหมด',
    'lottery.tabs.stores': 'ร้านค้า',
    'stores.title': 'ร้านค้า',
    'stores.search_label': 'ค้นหาร้านค้า',
    'stores.recommended.title': 'ร้านสลากฯ แนะนำ',
    'stores.load_failed.title': 'โหลดร้านค้าไม่สำเร็จ',
    'stores.load_failed.message': 'กรุณาลองใหม่อีกครั้ง',
    'stores.empty.title': 'ไม่พบร้านค้า',
    'stores.empty.message': 'ลองเปลี่ยนคำค้นหา หรือกลับมาใหม่อีกครั้ง',
    'stores.fallback_store_name': 'ร้านสลากฯ',
    'stores.code': 'รหัสร้าน {code}',
    'stores.lotteries.title': 'ร้านสลากหกหลักแบบดิจิทัล',
    'stores.lotteries.subtitle': 'ค้นหาเลขสลากฯ ในร้านค้า',
    'stores.lotteries.load_failed.title': 'โหลดเลขสลากไม่สำเร็จ',
    'stores.lotteries.load_failed.message': 'กรุณาลองใหม่อีกครั้ง',
    'stores.lotteries.empty.title': 'ยังไม่มีสลากให้เลือก',
    'stores.lotteries.empty.message':
        'ร้านค้านี้ยังไม่มีสลากที่พร้อมจำหน่ายในงวดปัจจุบัน',
    'stores.ticket.available': 'พร้อมขาย',
    'stores.ticket.sold_out': 'หมดแล้ว',
    'affiliate.title': 'ตัวแทนจำหน่าย',
    'affiliate.back_tooltip': 'กลับ',
    'affiliate.refresh_tooltip': 'รีเฟรช',
    'affiliate.load_failed': 'โหลดข้อมูล Affiliate ไม่สำเร็จ',
    'affiliate.register.store_name_required': 'กรุณากรอกชื่อร้านก่อนสมัคร',
    'affiliate.register.success': 'สมัครเป็นตัวแทนจำหน่ายสำเร็จ',
    'affiliate.register.failed': 'สมัคร Affiliate ไม่สำเร็จ',
    'affiliate.withdraw.minimum': 'ถอนขั้นต่ำ {amount}',
    'affiliate.withdraw.exceeds': 'ยอดถอนเกินยอดถอนได้',
    'affiliate.withdraw.bank_required': 'กรุณาบันทึกบัญชีรับเงินก่อนถอน',
    'affiliate.withdraw.success': 'ส่งคำขอถอนสำเร็จ',
    'affiliate.withdraw.failed': 'ถอนเงินไม่สำเร็จ กรุณาลองใหม่',
    'affiliate.link_copied': 'คัดลอกลิงก์แล้ว',
    'affiliate.pin.invalid': 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง',
    'affiliate.pin.locked': 'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่',
    'affiliate.pin.setup_required':
        'กรุณาตั้งค่า PIN ก่อนเข้าใช้ระบบ Affiliate',
    'affiliate.pin.failed': 'ไม่สามารถยืนยัน PIN ได้ กรุณาลองใหม่อีกครั้ง',
    'affiliate.pin.title': 'ใส่รหัส PIN 6 หลัก',
    'affiliate.pin.subtitle': 'เพื่อเข้าใช้ระบบ Affiliate',
    'affiliate.hero.fallback': 'ตัวแทนจำหน่าย',
    'affiliate.hero.subtitle': 'แนะนำผู้อื่นเพื่อรับผลตอบแทนการขาย',
    'affiliate.store_summary.label': 'ชื่อร้านของคุณ',
    'affiliate.store_summary.description':
        'ชื่อนี้จะแสดงให้ลูกค้าที่เข้าผ่านลิงก์แนะนำเห็น',
    'affiliate.register.title': 'เริ่มเป็นตัวแทนจำหน่าย',
    'affiliate.register.description':
        'กรอกชื่อร้านที่จะแสดงให้ลูกค้าเห็น แล้วระบบจะสร้างรหัสแนะนำให้ทันที',
    'affiliate.register.store_label': 'ชื่อร้าน',
    'affiliate.register.store_hint': 'เช่น ร้านโชคดีออนไลน์',
    'affiliate.register.button': 'สมัครเป็นตัวแทนจำหน่าย',
    'affiliate.stats.available.title': 'ยอดถอนได้',
    'affiliate.stats.available.subtitle': 'พร้อมถอน',
    'affiliate.stats.approved.title': 'อนุมัติแล้ว',
    'affiliate.stats.approved.subtitle': 'คอมมิชชัน',
    'affiliate.stats.pending.title': 'รอตรวจ',
    'affiliate.stats.pending.subtitle': 'รออนุมัติ',
    'affiliate.stats.converted.title': 'ยอดสำเร็จ',
    'affiliate.stats.converted.subtitle': 'รายการ',
    'affiliate.stats.visitors.title': 'กดลิงก์',
    'affiliate.stats.visitors.subtitle': 'ผู้เข้าชม',
    'affiliate.stats.registered.title': 'สมัครผ่านลิงก์',
    'affiliate.stats.registered.subtitle': 'บัญชี',
    'affiliate.tab.overview': 'ภาพรวม',
    'affiliate.tab.withdraw': 'ถอน',
    'affiliate.tab.commissions': 'คอม',
    'affiliate.tab.payouts': 'ประวัติ',
    'affiliate.referral.title': 'ลิงก์แนะนำ',
    'affiliate.referral.description':
        'แชร์ลิงก์นี้ให้เพื่อนสมัครหรือซื้อผ่านร้าน',
    'affiliate.referral.empty': 'ยังไม่มีลิงก์แนะนำ',
    'affiliate.referral.copy_tooltip': 'คัดลอกลิงก์',
    'affiliate.bank.title': 'บัญชีรับเงิน',
    'affiliate.bank.description': 'ใช้บัญชีเดียวกับบัญชีรับเงินรางวัล',
    'affiliate.bank.empty': 'ยังไม่ได้บันทึกบัญชีรับเงิน',
    'affiliate.edit': 'แก้ไข',
    'affiliate.withdraw.title': 'ขอถอนเงิน',
    'affiliate.withdraw.description': 'ถอนได้ไม่เกินยอดคงเหลือที่อนุมัติแล้ว',
    'affiliate.withdraw.amount_label': 'จำนวนเงิน (บาท)',
    'affiliate.withdraw.method_label': 'ช่องทางถอน',
    'affiliate.withdraw.bank_transfer': 'โอนเข้าบัญชีรับเงิน',
    'affiliate.withdraw.bank_description':
        'บัญชีนี้จะถูกใช้กับการถอนค่าคอมมิชชันด้วย',
    'affiliate.withdraw.wallet_credit': 'เติมเข้า wallet',
    'affiliate.withdraw.bank_missing':
        'ยังไม่มีบัญชีรับเงิน กรุณาบันทึกก่อนถอน',
    'affiliate.withdraw.submit': 'ส่งคำขอถอน',
    'affiliate.commissions.empty': 'ยังไม่มีรายการคอมมิชชัน',
    'affiliate.payouts.empty': 'ยังไม่มีรายการถอน',
    'affiliate.payout_method.wallet_credit': 'เติมเข้า wallet',
    'affiliate.payout_method.bank_transfer': 'โอนเข้าบัญชี',
    'affiliate.status.active': 'ใช้งานอยู่',
    'affiliate.status.calculated': 'รออนุมัติ',
    'affiliate.status.approved': 'อนุมัติแล้ว',
    'affiliate.status.pending': 'รอดำเนินการ',
    'affiliate.status.paid': 'จ่ายแล้ว',
    'affiliate.status.reversed': 'กลับรายการ',
    'affiliate.status.rejected': 'ไม่อนุมัติ',
    'tickets.title': 'สลากฯ ของฉัน',
    'tickets.loading': 'กำลังโหลดสลากฯ',
    'tickets.load_failed': 'โหลดสลากฯ ไม่สำเร็จ',
    'tickets.history_tooltip': 'ประวัติสลาก',
    'tickets.current_draw.title': 'งวดปัจจุบัน',
    'tickets.current_draw.subtitle':
        'สลากที่ซื้อแล้วและรายการที่รอขึ้นเงินจะแสดงแยกตามสถานะ',
    'tickets.search_numbers': 'ค้นหาเลขสลาก',
    'tickets.search.placeholder': 'ค้นหาเลขสลากฯ ในคลังของฉัน',
    'tickets.search.submit': 'ค้นหา',
    'tickets.search.clear': 'ล้างคำค้นหา',
    'tickets.search.result': 'ผลการค้นหา "{query}"',
    'tickets.search.empty.title': 'ไม่พบเลขสลากฯ ที่ค้นหาในคลังของฉัน',
    'tickets.search.empty.subtitle':
        'ลองค้นหาด้วยเลขอื่น หรือกลับไปดูสลากทั้งหมดในงวดนี้',
    'tickets.draw_date_label': 'สลากฯ งวดวันที่',
    'tickets.total_count': 'ทั้งหมด {count} ใบ',
    'tickets.winning_banner.title': 'ยินดีด้วย!',
    'tickets.winning_banner.message': 'คุณถูกรางวัล {count} ใบ',
    'tickets.tab.current': 'งวดปัจจุบัน',
    'tickets.tab.history': 'งวดย้อนหลัง',
    'tickets.empty.title': 'ยังไม่มีสลากฯ ในงวดนี้',
    'tickets.empty.subtitle': 'เมื่อซื้อสลากสำเร็จ รายการจะถูกแสดงบนหน้านี้',
    'tickets.footer_note':
        'เมนู ‘สลากฯ ของฉัน’ เป็นการบันทึกเลขสลากฯ หากถูกรางวัล ระบบจะแจ้งผลรางวัลในหน้านี้',
    'tickets.number_fallback': 'เลขสลาก',
    'tickets.stub.digital_label': 'สลากดิจิทัล',
    'tickets.stub.series_label': 'L6',
    'tickets.stub.price_label': '80\nบาท',
    'tickets.stub.claim_start': 'ขึ้นรางวัล',
    'tickets.stub.prize_amount': 'รับเงินรางวัล {amount}',
    'tickets.count': '{count} ใบ',
    'tickets.status.winning': 'ถูกรางวัล',
    'tickets.status.non_winning': 'ไม่ถูกรางวัล',
    'tickets.status.claim_failed': 'ขึ้นเงินไม่สำเร็จ',
    'tickets.status.claim_cancelled': 'ยกเลิกขึ้นเงิน',
    'tickets.status.approved': 'อนุมัติแล้ว',
    'tickets.status.paid': 'ขึ้นเงินแล้ว',
    'tickets.status.pending_claim': 'รอรับเงินรางวัล',
    'tickets.status.pending_result': 'รอออกผล',
    'tickets.prize.more': '{prize} และอีก {count} รางวัล',
    'tickets.prize.first_prize': 'รางวัลที่ 1',
    'tickets.prize.near_first_prize': 'รางวัลข้างเคียงรางวัลที่ 1',
    'tickets.prize.second_prize': 'รางวัลที่ 2',
    'tickets.prize.third_prize': 'รางวัลที่ 3',
    'tickets.prize.fourth_prize': 'รางวัลที่ 4',
    'tickets.prize.fifth_prize': 'รางวัลที่ 5',
    'tickets.prize.front3': 'รางวัลเลขหน้า 3 ตัว',
    'tickets.prize.back3': 'รางวัลเลขท้าย 3 ตัว',
    'tickets.prize.back2': 'รางวัลเลขท้าย 2 ตัว',
    'tickets.prize.fallback': 'ถูกรางวัล',
    'tickets.history.title': 'ประวัติสลาก',
    'tickets.current_tooltip': 'งวดปัจจุบัน',
    'tickets.history.header.title': 'สลากงวดย้อนหลัง',
    'tickets.history.header.subtitle':
        'แสดงเฉพาะงวดที่ออกผลแล้วและมีงวดใหม่กว่าแล้ว',
    'tickets.history.list_title': 'รายการสลากฯ',
    'tickets.history.show_winning': 'ดูสลากฯ ที่ถูกรางวัล',
    'tickets.history.show_all': 'ดูสลากฯ ทั้งหมด',
    'tickets.history.no_winning_summary':
        'วันนี้อาจไม่ใช่วันของเรา เจอกันใหม่โอกาสหน้า',
    'tickets.history.past_tickets_label': 'สลากฯ ย้อนหลัง',
    'tickets.history.completed_draw_fallback': 'งวดที่ออกผลแล้ว',
    'tickets.history.all_draws': 'ทุกงวดที่ออกผลแล้ว {count} งวด',
    'tickets.history.item_count': '{count} รายการ',
    'tickets.history.load_failed': 'โหลดประวัติสลากไม่สำเร็จ',
    'tickets.history.load_more_failed': 'โหลดรายการเพิ่มเติมไม่สำเร็จ',
    'tickets.history.empty.title': 'ยังไม่มีสลากย้อนหลัง',
    'tickets.history.empty.subtitle':
        'เมื่อมีงวดใหม่และงวดเดิมออกผลแล้ว รายการจะแสดงที่นี่',
    'tickets.history.winning_empty.title': 'ไม่พบสลากฯ ที่ถูกรางวัลในงวดนี้',
    'tickets.history.winning_empty.subtitle':
        'กลับไปดูสลากทั้งหมด หรือลองตรวจงวดย้อนหลังอีกครั้ง',
    'common.loading_more': 'กำลังโหลด...',
    'common.load_more': 'โหลดเพิ่มเติม',
    'common.all_loaded': 'แสดงครบทั้งหมดแล้ว',
    'tickets.detail.title': 'รายละเอียดสลาก',
    'common.back': 'ย้อนกลับ',
    'tickets.not_found': 'ไม่พบข้อมูลสลาก',
    'tickets.label.lottery_number': 'เลขสลาก',
    'tickets.label.draw': 'งวด',
    'tickets.label.draw_date': 'วันที่ออกผล',
    'tickets.label.lottery_draw_date': 'สลากฯ งวดวันที่',
    'tickets.label.draw_number': 'งวดที่',
    'tickets.label.set_number': 'ชุดที่',
    'tickets.label.count': 'จำนวน',
    'tickets.label.prize_amount': 'เงินรางวัล',
    'tickets.label.recipient': 'ผู้รับเงิน',
    'tickets.label.payout_channel': 'ช่องทาง',
    'tickets.label.net_amount': 'ยอดเงินที่ได้รับ',
    'tickets.label.submitted_at': 'วันที่ทำรายการ',
    'tickets.label.prize': 'รางวัล',
    'tickets.label.government_lottery': 'สลากกินแบ่งรัฐบาล',
    'tickets.claim.view_claim': 'ดูรายการขึ้นเงิน',
    'tickets.claim.view_reward': 'ดูรางวัล',
    'tickets.claim.start': 'ขึ้นเงินรางวัล',
    'tickets.claim.pin_title': 'ใส่รหัส PIN',
    'tickets.claim.title': 'ขึ้นเงินรางวัล',
    'tickets.claim.confirm_title': 'ยืนยันการขึ้นเงินรางวัล',
    'tickets.claim.already_claimed.title': 'มีรายการขึ้นเงินแล้ว',
    'tickets.claim.already_claimed.subtitle':
        'ติดตามสถานะรายการนี้ได้จากหน้ารายละเอียด',
    'tickets.claim.loading': 'กำลังโหลดข้อมูลรางวัล...',
    'tickets.claim.load_failed': 'โหลดข้อมูลขึ้นเงินไม่สำเร็จ',
    'tickets.claim.submit_failed': 'ส่งรายการไม่สำเร็จ กรุณาลองใหม่',
    'tickets.claim.biometric_unavailable': 'ไม่สามารถยืนยันด้วยชีวมิติได้',
    'tickets.claim.biometric_failed': 'ยืนยันด้วยชีวมิติไม่สำเร็จ กรุณาใช้ PIN',
    'tickets.claim.pin_invalid': 'PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง',
    'tickets.claim.pin_locked':
        'กรอก PIN ผิดเกินกำหนด กรุณารอสักครู่แล้วลองใหม่',
    'tickets.claim.pin_setup_required': 'กรุณาตั้งค่า PIN ก่อนทำรายการ',
    'tickets.claim.pin_assertion_invalid':
        'การยืนยันด้วยชีวมิติหมดอายุ กรุณายืนยัน PIN อีกครั้ง',
    'tickets.claim.conflict': 'รายการนี้ถูกดำเนินการแล้ว กรุณารีเฟรชสถานะ',
    'tickets.claim.payout_method_title': 'ช่องทางขึ้นเงินรางวัล',
    'tickets.claim.wallet.title': 'G Wallet',
    'tickets.claim.wallet.account_title': 'G Wallet x {suffix}',
    'tickets.claim.wallet.subtitle': 'รับเงินเข้า G-Wallet ภายใน 2 ชั่วโมง',
    'tickets.claim.bank.title': 'บัญชีธนาคาร',
    'tickets.claim.bank.subtitle_ready': 'รับเงินเข้าบัญชีธนาคารที่ตั้งไว้',
    'tickets.claim.bank.subtitle_missing':
        'เพิ่มบัญชีรับเงินรางวัลก่อนเลือกช่องทางนี้',
    'tickets.claim.bank.account_number': 'หมายเลขบัญชี',
    'tickets.claim.add_bank': 'เพิ่มบัญชีรับเงินรางวัล',
    'tickets.claim.unavailable.pending_result': 'สลากใบนี้ยังรอออกผล',
    'tickets.claim.unavailable.non_winning': 'สลากใบนี้ไม่ถูกรางวัลในงวดนี้',
    'tickets.claim.unavailable.winning_not_open':
        'พบรายการถูกรางวัลแล้ว แต่ยังรอเปิดให้ขึ้นเงินอย่างเป็นทางการ',
    'tickets.claim.unavailable.default': 'รายการนี้ยังไม่สามารถขึ้นเงินได้',
    'tickets.claim.enter_pin': 'ใส่รหัส PIN 6 หลัก',
    'tickets.claim.processing.title': 'กำลังดำเนินการโอนเงินรางวัล',
    'tickets.claim.processing.subtitle':
        'เงินรางวัลจะถึงบัญชีผู้รับเงินภายใน 2 ชั่วโมง หลังจากทำรายการสำเร็จ',
    'tickets.claim.view_my_tickets': 'ดูสลากฯ ของฉัน',
    'tickets.image.unavailable': 'ไม่สามารถแสดงรูปสลากได้',
    'tickets.image.preparing': 'รูปสลากกำลังเตรียมพร้อม',
    'tickets.image.open_preview': 'ดูรูปสลากฯ',
    'tickets.image.close_preview': 'ปิดรูปสลากฯ',
    'tickets.image.alt': 'รูปสลากฯ เลข {number}',
    'tickets.image.government_lottery_english': 'THAI GOVERNMENT LOTTERY',
    'tickets.image.digital_watermark': 'DIGITAL',
    'tickets.image.digital_number_label': 'เลขสลากฯ ดิจิทัล',
    'tickets.image.current_draw': 'งวดปัจจุบัน',
    'tickets.image.digital_type': 'แบบดิจิทัล',
    'tickets.image.sold': 'ขายแล้ว',
    'tickets.image.tenant_fallback': 'แอป',
    'tickets.image.modal_note':
        'สลากดิจิทัลนี้จัดเก็บใน {site} สำหรับ {product}',
  },
  'en-US': {
    'bottom_nav.home': 'Home',
    'bottom_nav.tickets': 'My Tickets',
    'bottom_nav.wallet': 'Wallet',
    'bottom_nav.more': 'More',
    'common.language': 'Language',
    'common.thai': 'ไทย',
    'common.english': 'English',
    'common.money.baht_suffix': 'THB',
    'app_alert.default_title': 'Notice',
    'app_alert.default_button': 'OK',
    'app_splash.preparing': 'Preparing system data',
    'sale_closure.alert_message':
        'You have been moved to the waiting-for-results page. Please check the results after they are announced.',
    'routes.home.title': 'Home',
    'routes.home.description':
        'Number search, wallet, activities, news, and latest results',
    'routes.buy.title': 'Buy Lottery',
    'routes.buy.description': 'Search, select, and reserve digital tickets',
    'routes.buy_search.title': 'Search Lottery Numbers',
    'routes.buy_search.description':
        'Search 6-digit numbers and keep your previous search state',
    'routes.search.title': 'Search Lottery Numbers',
    'routes.buy_more.title': 'More Like This Number',
    'routes.buy_more.description':
        'Show nearby ticket numbers from the previous search',
    'routes.cart.title': 'Lottery Cart',
    'routes.checkout.title': 'Checkout',
    'routes.checkout_pending.title': 'Pending Payment',
    'routes.tickets.title': 'My Tickets',
    'routes.tickets.description':
        'Current tickets, ticket history, and claim status',
    'routes.tickets_history.title': 'Ticket History',
    'routes.tickets_view.title': 'Ticket Image',
    'routes.ticket_claim.title': 'Claim Ticket Prize',
    'routes.result.title': 'Results',
    'routes.result.description':
        'Unofficial live results and published prize results',
    'routes.result_full.title': 'Full Results',
    'routes.results.title': 'Results',
    'routes.results_full.title': 'Full Results',
    'routes.waiting_result.title': 'Waiting for Results',
    'routes.my_wallet.title': 'My Wallet',
    'routes.my_wallet.description':
        'Balance, top-up actions, and recent wallet transactions',
    'routes.topup.title': 'Top up G-Wallet',
    'routes.topup_history.title': 'Top-up History',
    'routes.reward_claims.title': 'Reward Claims',
    'routes.reward_claim_detail.title': 'Reward Claim Detail',
    'routes.activity_claims.title': 'Activity Reward Claim History',
    'routes.activity_claim_detail.title': 'Activity Reward Claim Detail',
    'routes.activities.title': 'Activities',
    'routes.activities.description':
        'Current draw activities and past draw activities',
    'routes.activities_history.title': 'Past Activities',
    'routes.activity_detail.title': 'Activity Detail',
    'routes.affiliate.title': 'Affiliate',
    'routes.profile.title': 'Profile',
    'routes.profile_auto_reward.title': 'Auto Reward Claim',
    'routes.profile_line_notifications.title': 'LINE Notifications',
    'routes.profile_reward_bank.title': 'Reward Bank Account',
    'routes.profile_biometrics.title': 'Biometric Devices',
    'routes.profile_account_deletion.title': 'Delete Account',
    'routes.purchase_history.title': 'Purchase History',
    'routes.purchase_history_detail.title': 'Purchase Detail',
    'routes.stores.title': 'Stores',
    'routes.store_lotteries.title': 'Store Lotteries',
    'routes.news.title': 'News',
    'routes.news_detail.title': 'News Detail',
    'routes.terms.title': 'Terms and Conditions',
    'routes.privacy.title': 'Privacy Policy',
    'routes.term_reward.title': 'Reward Terms',
    'routes.lottery_knowledge.title': 'Lottery Buying Knowledge',
    'routes.login.title': 'Sign In',
    'routes.register.title': 'Create Account',
    'routes.forgot_password.title': 'Forgot Password',
    'routes.reset_password.title': 'Reset Password',
    'routes.line_callback.title': 'LINE Callback',
    'routes.line_link_phone.title': 'Link LINE Account',
    'routes.social_callback.title': 'Social Login Callback',
    'routes.social_link_phone.title': 'Link Social Account',
    'routes.pin.title': 'Verify PIN',
    'routes.security_lock.title': 'Security Lock',
    'routes.maintenance.title': 'Maintenance',
    'routes.account_suspended.title': 'Account Suspended',
    'routes.countdown.title': 'Waiting for Sale',
    'routes.success.title': 'Success',
    'routes.badge.sensitive': 'Sensitive',
    'routes.badge.public': 'Public',
    'routes.group.storefront': 'Storefront',
    'routes.group.lottery': 'Lottery',
    'routes.group.wallet': 'Wallet',
    'routes.group.account': 'Account',
    'routes.group.content': 'Content',
    'routes.group.system': 'System',
    'auth.login.title': 'Sign in',
    'auth.login.hero_badge': 'Digital lottery',
    'auth.login.hero_description':
        'Buy, check, and manage your lottery tickets in one place.',
    'auth.login.form_title': 'Verify your identity',
    'auth.login.form_description':
        'Use the phone number linked to your account.',
    'auth.login.identifier_label': 'Phone or email',
    'auth.login.identifier_hint': 'Enter your phone number',
    'auth.login.password_label': 'Password',
    'auth.login.password_hint': 'Enter your password',
    'auth.login.submit': 'Sign in',
    'auth.login.submitting': 'Signing in',
    'auth.login.register': 'Create account',
    'auth.login.register_prompt': 'No account yet?',
    'auth.login.forgot_password': 'Forgot password?',
    'auth.login.remember_me': 'Remember me',
    'auth.login.divider': 'or',
    'auth.login.show_password': 'Show password',
    'auth.login.hide_password': 'Hide password',
    'auth.login.social_continue': 'Continue with {provider}',
    'auth.login.social_opening': 'Connecting to {provider}',
    'auth.login.failed': 'Could not sign in',
    'auth.login.social_link_missing': 'Sign-in link was not found',
    'auth.login.social_failed': 'Could not sign in with this provider',
    'auth.validation.required': 'Please fill in this field.',
    'auth.validation.phone_invalid': 'Please enter a valid phone number.',
    'auth.validation.otp_invalid': 'Please enter a 6-digit OTP.',
    'auth.validation.confirm_password_required':
        'Please confirm your password.',
    'auth.validation.password_mismatch': 'Passwords do not match.',
    'auth.otp.sent_to': 'Code sent to {phone}',
    'auth.otp.resend_in': 'Resend in {seconds}s',
    'auth.otp.resend': 'Resend code',
    'auth.otp.label': '6-digit OTP',
    'auth.otp.verification_failed':
        'OTP verification failed. Please request a new code.',
    'auth.register.title': 'Create account',
    'auth.register.hero_badge': 'Paotang account',
    'auth.register.hero_description':
        'Create an account to buy, check tickets, and keep your records safe.',
    'auth.register.form_title': 'Account information',
    'auth.register.form_description':
        'Enter details that match the phone number you use.',
    'auth.register.header_title': 'Create customer account',
    'auth.register.header_subtitle':
        'Verify your phone number with OTP before getting started.',
    'auth.register.first_name': 'First name',
    'auth.register.first_name_hint': 'Enter first name',
    'auth.register.last_name': 'Last name',
    'auth.register.last_name_hint': 'Enter last name',
    'auth.register.phone': 'Phone number',
    'auth.register.phone_hint': 'Enter phone number',
    'auth.register.password': 'Password',
    'auth.register.password_hint': 'Set password',
    'auth.register.confirm_password': 'Confirm password',
    'auth.register.confirm_password_hint': 'Enter password again',
    'auth.register.show_password': 'Show password',
    'auth.register.hide_password': 'Hide password',
    'auth.register.terms': 'Accept terms and conditions',
    'auth.register.otp_title': 'Verify OTP',
    'auth.register.otp_hint': 'Enter OTP',
    'auth.register.submit': 'Create account',
    'auth.register.submit_with_otp': 'Verify and create account',
    'auth.register.submitting': 'Creating account',
    'auth.register.login_link': 'Already have an account? Sign in',
    'auth.register.login_prompt': 'Already have an account?',
    'auth.register.terms_required':
        'Please accept the terms and conditions before creating an account.',
    'auth.register.failed':
        'Could not create account. Please check your details and try again.',
    'auth.forgot.title': 'Forgot password',
    'auth.forgot.hero_title': 'Reset your password',
    'auth.forgot.hero_description':
        'Verify with OTP, then set a new password right away.',
    'auth.forgot.title_phone': 'Reset password by OTP',
    'auth.forgot.title_otp': 'Verify OTP',
    'auth.forgot.title_password': 'Set new password',
    'auth.forgot.title_done': 'Password updated',
    'auth.forgot.description_phone':
        'Enter the phone number used for registration to receive an OTP.',
    'auth.forgot.description_otp': 'Enter the 6-digit code sent to your phone.',
    'auth.forgot.description_otp_sent_to':
        'Enter the 6-digit code sent to {phone}.',
    'auth.forgot.description_password': 'Set a new password for this account.',
    'auth.forgot.description_done':
        'You can sign in with your new password now.',
    'auth.forgot.button_send_otp': 'Send OTP',
    'auth.forgot.button_verify_otp': 'Verify OTP',
    'auth.forgot.button_save_password': 'Save new password',
    'auth.forgot.back_to_login': 'Back to sign in',
    'auth.forgot.new_password': 'New password',
    'auth.forgot.confirm_new_password': 'Confirm new password',
    'auth.forgot.phone_hint': 'Enter your phone number',
    'auth.forgot.otp_hint': 'Enter OTP',
    'auth.forgot.password_hint': 'Set a new password',
    'auth.forgot.confirm_password_hint': 'Enter the password again',
    'auth.forgot.submitting': 'Processing',
    'auth.forgot.failed':
        'Could not complete this request. Please check your details and try again.',
    'auth.forgot.otp_provider_unavailable':
        'This store has not enabled OTP password reset yet. Use LINE or contact the store.',
    'auth.forgot.done_message': 'Your new password has been saved.',
    'auth.forgot.line_title': 'Reset with LINE',
    'auth.forgot.line_description':
        'If you have connected LINE to this account, verify with LINE and set a new password.',
    'auth.forgot.line_button': 'Reset with LINE',
    'auth.forgot.line_opening': 'Opening LINE',
    'auth.forgot.line_failed':
        'Could not reset with LINE. This account may not be connected to LINE, or the store has not configured LINE.',
    'auth.reset.title': 'Set new password',
    'auth.reset.header': 'New password',
    'auth.reset.line_description':
        'LINE verification succeeded. Set a new password to continue.',
    'auth.reset.link_description':
        'Use the link from the store admin to set a new password.',
    'auth.reset.card_description':
        'Enter your new password and confirm it matches.',
    'auth.reset.invalid_title': 'Invalid link',
    'auth.reset.invalid_message': 'Please request a new password reset link.',
    'auth.reset.new_password': 'New password',
    'auth.reset.new_password_hint': 'Enter new password',
    'auth.reset.confirm_new_password': 'Confirm new password',
    'auth.reset.confirm_new_password_hint': 'Enter it again',
    'auth.reset.show_password': 'Show password',
    'auth.reset.hide_password': 'Hide password',
    'auth.reset.save': 'Save new password',
    'auth.reset.submitting': 'Saving',
    'auth.reset.password_required': 'Please enter a new password.',
    'auth.reset.success': 'Password updated. Please sign in again.',
    'auth.reset.expired':
        'This link may have expired. Please request a new reset link.',
    'auth.social.callback.waiting':
        'Please wait while we verify your {provider} account.',
    'auth.social.callback.title': 'Signing in',
    'auth.social.callback.missing_code':
        'No verification data from {provider}. Please try connecting again.',
    'auth.social.callback.failed': 'Could not sign in with {provider}.',
    'auth.social.callback.connect_failed':
        'Could not connect to sign in with {provider}.',
    'auth.social.link.title': 'Link account with {provider}',
    'auth.social.link.phone_title': 'Verify phone number',
    'auth.social.link.phone_subtitle':
        'If this phone already has an account, we will check the existing password and link this social account immediately.',
    'auth.social.link.hero_subtitle':
        'Verify your phone number to use an existing account or create a new account with {provider}.',
    'auth.social.link.password_hint':
        'Existing account password or new password',
    'auth.social.link.confirm_password_hint':
        'Enter again to create a new account',
    'auth.social.link.submit': 'Verify and sign in',
    'auth.social.link.submitting': 'Verifying',
    'auth.social.link.missing':
        'Missing {provider} link information. Please start again.',
    'auth.social.link.failed': 'Could not link {provider} account.',
    'auth.social.profile.account': '{provider} account',
    'auth.social.profile.fallback_name': '{provider} customer',
    'auth.social.profile.ready': 'Ready to link account and sign in',
    'auth.social.profile.status': 'Ready to link',
    'pin.title': 'Enter 6-digit PIN',
    'pin.description': 'Enter your 6-digit PIN to continue.',
    'pin.setup.title': 'Set 6-digit PIN',
    'pin.setup.confirm_title': 'Confirm 6-digit PIN',
    'pin.setup.description':
        'Set a PIN to protect sensitive actions in this account.',
    'pin.setup.confirm_description': 'Enter the same PIN again to confirm.',
    'pin.setup.confirm_helper': 'Confirm the PIN you set.',
    'pin.setup.submitting': 'Setting up PIN...',
    'pin.verifying': 'Checking...',
    'pin.setup.mismatch': 'PINs do not match. Please set a new PIN.',
    'pin.setup.failed': 'Could not set PIN. Please try again.',
    'pin.use_biometric': 'Use Face ID / Biometric',
    'pin.biometric_reason': 'Authenticate to unlock and continue',
    'pin.biometric_unavailable': 'Biometric unlock is unavailable. Use PIN.',
    'pin.biometric_failed': 'Biometric unlock failed. Use PIN.',
    'pin.forgot': 'Forgot PIN?',
    'pin.invalid': 'Incorrect PIN. Please try again.',
    'pin.reset.title_request': 'Forgot PIN',
    'pin.reset.title_otp': 'Verify OTP',
    'pin.reset.title_pin': 'Set New PIN',
    'pin.reset.title_done': 'PIN Updated',
    'pin.reset.description_request': 'Verify by OTP before setting a new PIN.',
    'pin.reset.description_otp': 'Enter the 6-digit code sent by SMS.',
    'pin.reset.description_pin': 'Set a new 6-digit PIN for this account.',
    'pin.reset.description_confirm_pin': 'Enter the new PIN again to confirm.',
    'pin.reset.description_done': 'You can continue using the app now.',
    'pin.reset.request_info':
        'We will send an OTP to the phone number linked to this account before resetting your PIN.',
    'pin.reset.otp_label': '6-digit OTP',
    'pin.reset.otp_sent_to': 'Code sent to {phone}',
    'pin.reset.resend_in': 'Resend in {seconds}s',
    'pin.reset.resend': 'Resend code',
    'pin.reset.new_pin_label': 'New 6-digit PIN',
    'pin.reset.confirm_pin_label': 'Confirm new PIN',
    'pin.reset.pin_mismatch': 'PINs do not match',
    'pin.reset.done_message': 'Your PIN has been updated.',
    'pin.reset.back_to_app': 'Back to app',
    'pin.reset.back_to_pin': 'Back to PIN',
    'pin.reset.submit_otp': 'Verify OTP',
    'pin.reset.save_pin': 'Save new PIN',
    'pin.reset.send_otp': 'Send OTP',
    'pin.reset.otp_required': 'Please enter a 6-digit OTP.',
    'pin.reset.pin_required': 'Please enter a 6-digit PIN.',
    'pin.reset.failed': 'Could not reset PIN. Please try again.',
    'pin.reset.send_failed': 'Could not send OTP. Please try again.',
    'pin.reset.otp_provider_unavailable':
        'This store has not enabled OTP PIN reset yet. Contact the store to verify your identity.',
    'common.account_phone': 'your account phone',
    'security.capture.title': 'Screen capture is not allowed',
    'security.capture.description':
        'Sensitive information was hidden. Please unlock again to continue.',
    'security.capture.unlock_again': 'Unlock again',
    'common.view_all': 'View all',
    'common.retry': 'Try again',
    'common.cancel': 'Cancel',
    'common.wallet_balance': 'Wallet balance',
    'common.next': 'Next',
    'common.confirm': 'Confirm',
    'common.loading_data': 'Loading data...',
    'common.load_failed': 'Could not load data',
    'home.title': 'Home',
    'home.activities': 'Activities',
    'home.news': 'News',
    'home.action.topup': 'Top up',
    'home.action.tickets': 'Tickets',
    'home.action.claim': 'Claim',
    'home.action.history': 'History',
    'home.product_title': 'Six-digit lottery',
    'home.price.amount': '80',
    'home.price.unit': 'THB',
    'home.sale.label': 'Now on sale',
    'home.sale.amount': '30M tickets!',
    'home.buy_lottery.title': 'Buy digital lottery',
    'home.buy_lottery.subtitle':
        'Search numbers, reserve tickets, and checkout',
    'home.scan_lottery.title': 'Scan lottery tickets',
    'home.guest.title': 'Start buying digital lottery',
    'home.guest.subtitle':
        'Sign in or create an account before choosing and paying for tickets',
    'home.results.title': 'Lottery results',
    'home.results.subtitle': 'View unofficial live results and past results',
    'home.news_card.title': 'News',
    'home.news_card.subtitle': 'Announcements and updates from this store',
    'result.title': 'Lottery results',
    'result.full_title': 'Full lottery results',
    'result.loading': 'Loading lottery results...',
    'result.history_title': 'Past lottery results',
    'result.no_latest': 'No latest lottery results yet',
    'result.no_history': 'No past lottery results yet',
    'result.no_additional': 'No additional prize numbers yet',
    'result.payout_hint':
        'You can claim rewards at any Krungthai Bank, BAAC, Government Savings Bank branch, or the Government Lottery Office.',
    'result.pending_draw_date': 'Draw date pending',
    'result.unofficial': 'These are unofficial live results.',
    'result.draw_date': 'Draw date {date}',
    'result.prize_each': '{amount} per prize',
    'result.reward.reward_1': 'First prize',
    'result.reward.reward_2': 'Second prize',
    'result.reward.reward_3': 'Third prize',
    'result.reward.reward_4': 'Fourth prize',
    'result.reward.reward_5': 'Fifth prize',
    'result.reward.reward_beside_1': 'Adjacent first prize',
    'result.reward.reward_three_digit_1': 'Front 3 digits',
    'result.reward.reward_three_digit_2': 'Last 3 digits',
    'result.reward.reward_two_digit': 'Last 2 digits',
    'waiting_result.title': 'Waiting for results',
    'waiting_result.sale_closed': 'Lottery sales have ended',
    'waiting_result.resolved': 'Results announced',
    'waiting_result.pending': 'Waiting for result announcement',
    'waiting_result.my_tickets': 'My tickets',
    'waiting_result.check_result': 'Check results',
    'waiting_result.placeholder':
        'Prize numbers will display as xxxxxx until results are announced.',
    'waiting_result.live.title': 'Live result broadcast',
    'waiting_result.live.empty': 'The live broadcast will appear when ready.',
    'waiting_result.live.open': 'Open live broadcast',
    'waiting_result.live.open_failed': 'Unable to open live broadcast',
    'maintenance.title': '{site} is under maintenance',
    'maintenance.fallback_title': 'System is under maintenance',
    'maintenance.default_message':
        'Sorry for the inconvenience. Please come back later.',
    'maintenance.expected_end': 'Expected to return at {date}',
    'maintenance.support': 'Contact support {phone}',
    'maintenance.support_email': 'Contact support {email}',
    'maintenance.support_online': 'Contact support online',
    'maintenance.loading_title': 'Loading system status',
    'maintenance.loading_message': 'Please wait a moment',
    'account_suspended.permanent': 'Permanently suspended',
    'account_suspended.temporary': 'Temporarily suspended',
    'account_suspended.until': 'Until {date}',
    'account_suspended.kicker': 'Account suspended',
    'account_suspended.title': 'You cannot access the system',
    'account_suspended.message':
        'This customer account has been suspended by the store. Please review the reason below or contact support.',
    'account_suspended.reason': 'Reason',
    'account_suspended.no_reason': 'No reason provided',
    'account_suspended.duration': 'Suspension period',
    'account_suspended.back_to_login': 'Back to sign in',
    'account_suspended.contact_support': 'Contact support',
    'account_suspended.contact_support_online': 'Contact support online',
    'account_suspended.contact_support_with_phone': 'Contact support {phone}',
    'account_suspended.contact_support_with_email': 'Contact support {email}',
    'countdown.title': 'Waiting for sales',
    'countdown.waiting_title': 'Waiting for the next draw',
    'countdown.opens_in': 'Sales open in',
    'countdown.current_draw_fallback': 'Current draw',
    'countdown.sale_opens_at': 'Sales open {date}',
    'countdown.load_failed': 'Could not load draw information.',
    'countdown.unit.day': 'Days',
    'countdown.unit.hour': 'Hours',
    'countdown.unit.minute': 'Minutes',
    'countdown.unit.second': 'Seconds',
    'success.title': 'Transaction successful',
    'success.lottery_product_label': '',
    'success.purchase_title': 'Digital six-digit lottery purchase complete',
    'success.purchase_subtitle': 'You can view tickets from My Tickets.',
    'success.view_tickets': 'View my tickets',
    'success.save_receipt': 'Save',
    'success.receipt_saved': 'Payment receipt saved.',
    'success.share_receipt': 'Share',
    'success.receipt_share_started': 'Share options opened.',
    'success.receipt_share_failed_copied':
        'Could not share the receipt, so the details were copied.',
    'success.payment_loading': 'Loading payment information...',
    'success.payment_load_failed': 'Could not load payment information.',
    'success.transaction_at_label': 'Transaction date',
    'news.title': 'News',
    'news.detail_title': 'News details',
    'news.category': 'Announcement',
    'news.fallback_title': 'Announcement',
    'news.loading': 'Loading news',
    'news.load_failed.title': 'Could not load news',
    'news.load_failed.message': 'Please try again.',
    'news.empty.title': 'No news yet',
    'news.empty.message': 'Store news and announcements will appear here.',
    'news.missing.title': 'Announcement not found',
    'news.missing.message': 'This news item may have expired or been disabled.',
    'news.back_to_list': 'Back to news',
    'news.missing': 'This news item was not found.',
    'news.open_failed': 'Could not open this news item.',
    'news.modal.close': 'Close announcement',
    'content.terms.title': 'Terms and conditions',
    'content.terms.site_fallback': 'This website',
    'content.terms.section_title': 'Terms of use',
    'content.terms.default_content': 'Terms of use\n'
        '1. {site} is an online lottery distribution platform.\n'
        '2. The company does not support selling lottery tickets to anyone under 20 years old.\n'
        '3. The company supports people without regular income and people with disabilities becoming online lottery distributors.\n'
        '4. The company keeps purchased tickets safely for customers and supports reward claims for customers.\n'
        '5. If a buyer resells ticket images or physical tickets, the company is not involved and is not responsible for any damages.\n'
        '6. After placing an order and pressing "Pay", the company considers that the buyer has acknowledged all company terms and conditions.\n'
        '7. The company reserves the right to claim rewards for customers who bought tickets through the system without any extra charge.\n'
        '8. Customers may cancel lottery orders within 15 minutes in all cases. After that period, the company reserves the right not to refund ticket payments.',
    'content.privacy.title': 'Privacy policy',
    'content.privacy.section_title': 'Data protection',
    'content.privacy.hero_subtitle':
        'How {site} protects your personal information',
    'content.privacy.default_content': 'Privacy policy\n'
        '1. {site} uses personal information to provide lottery purchases, wallet topups, reward payouts, and transaction notifications.\n'
        '2. The system stores only information required by law and security standards.\n'
        '3. Customers can contact the store to request account correction, export, or deletion.\n'
        '4. Account deletion may still require retaining transaction records required by law.',
    'content.privacy.open_policy': 'Open full policy',
    'content.privacy.open_failed': 'Could not open the policy.',
    'content.reward_terms.title': 'Reward payout terms',
    'content.reward_terms.hero.title': 'Reward payout details',
    'content.reward_terms.hero.subtitle':
        'Each digital six-digit lottery set has 1 million tickets at 80 THB per ticket.',
    'content.reward_terms.office.abbr': 'GLO',
    'content.reward_terms.office.name': 'Government Lottery Office',
    'content.reward_terms.header.prize_type': 'Prize type',
    'content.reward_terms.header.count': 'Count',
    'content.reward_terms.header.amount': 'Prize value',
    'content.reward_terms.row.first.title': 'First prize',
    'content.reward_terms.row.first.count': '1 prize',
    'content.reward_terms.row.first.amount': '6,000,000 THB',
    'content.reward_terms.row.second.title': 'Second prize',
    'content.reward_terms.row.second.count': '5 prizes',
    'content.reward_terms.row.second.amount': '200,000 THB',
    'content.reward_terms.row.third.title': 'Third prize',
    'content.reward_terms.row.third.count': '10 prizes',
    'content.reward_terms.row.third.amount': '80,000 THB',
    'content.reward_terms.row.fourth.title': 'Fourth prize',
    'content.reward_terms.row.fourth.count': '50 prizes',
    'content.reward_terms.row.fourth.amount': '40,000 THB',
    'content.reward_terms.row.fifth.title': 'Fifth prize',
    'content.reward_terms.row.fifth.count': '100 prizes',
    'content.reward_terms.row.fifth.amount': '20,000 THB',
    'content.reward_terms.row.adjacent_first.title': 'Adjacent first prize',
    'content.reward_terms.row.adjacent_first.count': '2 prizes',
    'content.reward_terms.row.adjacent_first.amount': '100,000 THB',
    'content.reward_terms.row.front3.title': 'Front 3 digits',
    'content.reward_terms.row.front3.count': '2 draws\n2,000 prizes',
    'content.reward_terms.row.front3.amount': '4,000 THB',
    'content.reward_terms.row.last3.title': 'Last 3 digits',
    'content.reward_terms.row.last3.count': '2 draws\n2,000 prizes',
    'content.reward_terms.row.last3.amount': '4,000 THB',
    'content.reward_terms.row.last2.title': 'Last 2 digits',
    'content.reward_terms.row.last2.count': '1 draw\n10,000 prizes',
    'content.reward_terms.row.last2.amount': '2,000 THB',
    'content.knowledge.title': 'Lottery buying and selling knowledge',
    'content.knowledge.subtitle':
        'Important information for digital lottery buyers and sellers.',
    'content.knowledge.more_info': 'Learn more at',
    'content.knowledge.contact': 'www.glo.or.th or call 02-528-9682',
    'content.knowledge.section.digital_lottery.title':
        'Digital six-digit lottery',
    'content.knowledge.section.digital_lottery.item_1':
        'Do not resell digital six-digit lottery tickets through other channels.',
    'content.knowledge.section.digital_lottery.item_2':
        'Buyers receive the right to own digital six-digit lottery tickets after a successful purchase and cannot transfer that right to others.',
    'content.knowledge.section.digital_lottery.item_3':
        'Buying digital six-digit lottery tickets through an official app helps prevent fraud.',
    'content.knowledge.section.sellers.title':
        'For government lottery distributors',
    'content.knowledge.section.sellers.item_1':
        'Do not sell lottery tickets above the price set by the Government Lottery Office.',
    'content.knowledge.section.sellers.item_2':
        'Do not sell lottery tickets in educational institutions.',
    'content.knowledge.section.sellers.item_3':
        'Do not sell lottery tickets to people under 20 years old.',
    'lottery.buy.title': 'Buy digital lottery',
    'lottery.cart.tooltip': 'Lottery cart',
    'lottery.search.hero_title': 'Search lucky numbers',
    'lottery.search.hero_subtitle':
        'Enter some digits or all 6 digits to search tickets.',
    'lottery.search.button': 'Search numbers',
    'lottery.search.loading': 'Searching',
    'lottery.search.clear': 'Clear',
    'lottery.stock.title': 'Digital lottery numbers',
    'lottery.stock.subtitle': 'Results are shuffled every time they reload.',
    'lottery.filter.all': 'All',
    'lottery.filter.discount': 'Discounts',
    'lottery.filter.accessible_store': 'Accessible stores',
    'lottery.filter.agency_store': 'Agency stores',
    'lottery.search.page_title': 'Buy digital lottery',
    'lottery.search.card_title': 'Search lucky numbers',
    'lottery.search.store_card_title': 'Search store tickets',
    'lottery.search.number_label': 'Desired number',
    'lottery.search.again': 'Search again',
    'lottery.search.results_title': 'Search results',
    'lottery.search.results_subtitle':
        'Tap view more to search this number again.',
    'lottery.more.title': 'View more like this',
    'lottery.more.sheet_title': 'Lottery list',
    'lottery.more.number_prefix': 'Lottery number',
    'lottery.more.fallback': 'More lottery numbers',
    'lottery.more.subtitle': 'Items are shuffled to avoid ordered results.',
    'lottery.more.list_title': 'More numbers like this',
    'lottery.stock.show_new': 'Show new numbers',
    'lottery.stock.loading_new': 'Loading',
    'lottery.stock.refresh_cooldown': 'Wait {seconds}s',
    'lottery.stock.load_failed': 'Could not load lottery numbers.',
    'lottery.stock.not_found.title': 'No lottery numbers found',
    'lottery.stock.not_found.message':
        'Try another number or come back again later.',
    'lottery.stock.added_to_cart': 'Ticket added to cart.',
    'lottery.stock.removed_from_cart': 'Ticket removed from cart.',
    'lottery.stock.cart_action': 'Cart',
    'lottery.stock.action_failed': 'Could not complete this action.',
    'lottery.stock.reservation_unavailable.title':
        'This ticket has been purchased',
    'lottery.stock.reservation_unavailable.message':
        'Sorry, the selected ticket has already been purchased. Please choose another ticket.',
    'lottery.stock.reservation_unavailable.action': 'OK',
    'lottery.stock.view_more': 'View more like this',
    'lottery.stock.select': 'Select',
    'lottery.stock.selecting': 'Reserving',
    'lottery.stock.sold_out': 'Sold out',
    'lottery.stock.sale_closed.title': 'Lottery purchases are unavailable',
    'lottery.stock.sale_closed.message':
        'Reservations for this draw are closed. You can still review tickets or continue with reserved cart items.',
    'lottery.stock.sale_closed.action': 'Closed',
    'lottery.stock.remove': 'Remove',
    'lottery.stock.removing': 'Removing',
    'cart.title': 'Lottery cart',
    'cart.reserved_title': 'Reserved items',
    'cart.empty_subtitle': 'No tickets in cart yet',
    'cart.header_count': '{count} lottery ticket(s)',
    'cart.summary': '{count} ticket(s) • {total}',
    'cart.draw_date': 'Draw date {date}',
    'cart.load_failed_title': 'Could not load cart',
    'cart.loading': 'Loading reserved tickets...',
    'cart.empty_title': 'Cart is empty',
    'cart.empty_message': 'Choose lottery tickets before checkout.',
    'cart.find_tickets': 'Find lottery numbers',
    'cart.selection.title': 'You have selected tickets',
    'cart.selection.count_label': 'Selected quantity',
    'cart.selection.review': 'Review tickets',
    'cart.purchase_limit_message':
        'You can select up to 20 lottery tickets\nper checkout.',
    'cart.add_more_tickets': 'Add more tickets',
    'cart.checkout': 'Checkout',
    'cart.generic_retry': 'Please try again.',
    'cart.remove_group_title.single': 'Remove lottery ticket\n{number}?',
    'cart.remove_group_title.multiple':
        'Remove lottery tickets\n{number}, {count} tickets?',
    'cart.remove_group_message.single':
        'After confirmation, this ticket will be removed from checkout.',
    'cart.remove_group_message.multiple':
        'After confirmation, this ticket set will be removed from checkout.',
    'cart.remove_group_confirm': 'Remove',
    'cart.remove_group_removing': 'Removing...',
    'cart.reservation_title': '{count} reserved ticket(s)',
    'cart.expires_in': 'Reservation expires in {minutes} min',
    'cart.expires_countdown': 'Please pay within {time}',
    'cart.expired': 'Payment time expired',
    'cart.expired_release_message':
        'The reserved tickets in this cart have been released.',
    'checkout.title': 'Checkout',
    'checkout.summary_title': 'Order summary',
    'checkout.ticket_count': 'Ticket quantity',
    'checkout.summary_total': 'Total payment',
    'checkout.total': 'Amount due',
    'checkout.wallet_balance': 'Wallet balance',
    'checkout.payment_method_title': 'Payment method',
    'checkout.wallet_fallback_name': 'G Wallet',
    'checkout.wallet_payment_note':
        'Confirm payment to pay for lottery tickets automatically with the linked wallet account.',
    'checkout.wallet_loading': 'Loading wallet...',
    'checkout.wallet_load_failed': 'Could not load wallet.',
    'checkout.external_payment.name': 'External payment provider',
    'checkout.external_payment.subtitle':
        'Open the payment page configured by this store.',
    'checkout.external_payment.note':
        'Confirming creates a pending order and opens the external payment page.',
    'checkout.open_payment_failed': 'Could not open the payment page.',
    'checkout.pending.title': 'Pending payment',
    'checkout.pending.loading': 'Checking payment status...',
    'checkout.pending.message':
        'A payment order has been created. Complete payment on the external provider page, then return here to check the status again.',
    'checkout.pending.paid_title': 'Payment completed',
    'checkout.pending.paid_message':
        'We have received payment for this order. You can view the receipt now.',
    'checkout.pending.no_order_title': 'No pending payment found',
    'checkout.pending.no_order_message':
        'Return to checkout or choose lottery tickets again.',
    'checkout.pending.reference_label': 'Reference',
    'checkout.pending.status_label': 'Status',
    'checkout.pending.amount_label': 'Amount due',
    'checkout.pending.open_payment': 'Open payment page',
    'checkout.pending.refresh': 'Check status again',
    'checkout.pending.view_receipt': 'View receipt',
    'checkout.pending.status.pending': 'Pending payment',
    'checkout.pending.status.paid': 'Paid',
    'checkout.pending.status.failed': 'Payment failed',
    'checkout.pending.status.expired': 'Expired',
    'checkout.pending.status.unknown': 'Checking status',
    'checkout.payment_timer': 'Please pay within {time}',
    'checkout.load_failed_title': 'Could not load checkout',
    'checkout.preparing': 'Preparing payment item...',
    'checkout.no_payment_title': 'No checkout item',
    'checkout.no_payment_message':
        'Your cart is empty or the reservation has expired.',
    'checkout.back_to_buy': 'Back to ticket search',
    'checkout.insufficient.title': 'Insufficient balance',
    'checkout.insufficient.subtitle': 'Top up before paying for tickets.',
    'checkout.submitting': 'Paying...',
    'checkout.confirm': 'Confirm payment',
    'checkout.failed': 'Payment failed',
    'profile.title': 'More',
    'profile.refresh_tooltip': 'Refresh',
    'profile.customer_account': 'Customer account',
    'profile.member_code': 'Member code: {code}',
    'profile.copy_member_code': 'Copy member code',
    'profile.copied_member_code': 'Member code copied',
    'profile.loading': 'Loading member information...',
    'profile.load_failed': 'Could not load member information',
    'profile.refresh_again': 'Please refresh and try again.',
    'profile.language.title': 'Display language',
    'profile.language.subtitle':
        'Choose the language for this app and system messages.',
    'profile.language.save_failed':
        'Language changed, but could not be saved to your account.',
    'profile.section.history': 'History',
    'profile.section.reward_settings': 'Reward payout settings',
    'profile.section.about': 'About this app',
    'profile.badge.new': 'New',
    'profile.badge.recommended': 'Recommended',
    'profile.menu.reward_bank': 'Reward payout account',
    'profile.menu.how_to_contact': 'How to buy/sell tickets and contact',
    'profile.reward_bank.load_failed': 'Could not load payout account.',
    'profile.reward_bank.incomplete':
        'Choose a bank and enter account name and account number.',
    'profile.reward_bank.saved': 'Payout account saved.',
    'profile.reward_bank.save_failed':
        'Could not save the account. Please check the details and try again.',
    'profile.reward_bank.pin_invalid': 'PIN is incorrect. Please try again.',
    'profile.reward_bank.pin_locked':
        'Too many incorrect PIN attempts. Please wait and try again.',
    'profile.reward_bank.pin_required':
        'Please set up or verify PIN before saving.',
    'profile.reward_bank.hero.title': 'Payout channel',
    'profile.reward_bank.hero.subtitle':
        'Used for reward payouts and affiliate withdrawals.',
    'profile.reward_bank.form.title': 'Bank account information',
    'profile.reward_bank.form.description':
        'Choose a Thai bank and enter the account name and number exactly as shown in the bank book.',
    'profile.reward_bank.form.bank': 'Bank',
    'profile.reward_bank.form.bank_options':
        'Bangkok Bank|Kasikornbank|Krungthai Bank|TMBThanachart Bank|Siam Commercial Bank|Bank of Ayudhya|Kiatnakin Phatra Bank|CIMB Thai Bank|TISCO Bank|United Overseas Bank Thai|Thai Credit Bank|Land and Houses Bank|ICBC Thai|Government Savings Bank|Bank for Agriculture and Agricultural Cooperatives|Government Housing Bank|Islamic Bank of Thailand|SME Development Bank of Thailand',
    'profile.reward_bank.form.account_name': 'Account name',
    'profile.reward_bank.form.account_name_hint': 'Account holder name',
    'profile.reward_bank.form.account_number': 'Account number',
    'profile.reward_bank.form.account_number_hint': 'Bank account number',
    'profile.reward_bank.form.save': 'Save payout account',
    'profile.reward_bank.preview.empty_title': 'No payout account saved',
    'profile.reward_bank.preview.empty_subtitle':
        'This account will be used for rewards and affiliate payouts.',
    'profile.reward_bank.pin.title': 'Enter 6-digit PIN',
    'profile.reward_bank.pin.subtitle': 'To save your payout account',
    'profile.menu.auto_reward': 'Automatic reward claim',
    'profile.auto_reward.load_failed': 'Could not load auto reward settings.',
    'profile.auto_reward.save_bank_first':
        'Please add a payout account before choosing bank transfer.',
    'profile.auto_reward.add_bank_first': 'Please add a payout account first.',
    'profile.auto_reward.saved': 'Automatic reward claim has been enabled.',
    'profile.auto_reward.save_failed':
        'Could not save settings. Please try again.',
    'profile.auto_reward.intro.subtitle': 'Convenient, simple, fast payouts',
    'profile.auto_reward.visual.credit_label': 'Payout',
    'profile.auto_reward.visual.credit_amount': '+3,940',
    'profile.auto_reward.visual.credit_currency': 'THB',
    'profile.auto_reward.benefit.convenient':
        'Convenient: no need to claim rewards manually',
    'profile.auto_reward.benefit.easy':
        'Easy: receive money in G Wallet or your bank account',
    'profile.auto_reward.benefit.fast': 'Fast payout after {reviewer} review',
    'profile.auto_reward.reviewer_fallback': 'the service provider',
    'profile.auto_reward.conditions.title': 'Setup conditions',
    'profile.auto_reward.conditions.auto_claim':
        'The system will claim every winning digital lottery ticket and send the payout to your selected primary channel automatically.',
    'profile.auto_reward.conditions.fee':
        'The bank may charge a service fee for digital lottery reward payouts to a bank account or Wallet.',
    'profile.auto_reward.conditions.change_before':
        'To change payout channel, update this setting before 16:00 on draw day.',
    'profile.auto_reward.conditions.no_retroactive':
        'This setting does not apply retroactively to winning tickets from past draws.',
    'profile.auto_reward.start_button': 'Set up automatic reward claim',
    'profile.auto_reward.info_tooltip': 'Information',
    'profile.auto_reward.select.title': 'Choose primary reward payout channel',
    'profile.auto_reward.select.subtitle':
        'The system will claim lottery rewards and submit the payout request to {reviewer} using your selected primary channel.',
    'profile.auto_reward.wallet.title': 'G Wallet',
    'profile.auto_reward.wallet.subtitle':
        'G Wallet can receive up to 500,000 THB.',
    'profile.auto_reward.bank.title': 'Bank account',
    'profile.auto_reward.bank.missing_subtitle':
        'Add a payout account before choosing this channel.',
    'profile.auto_reward.bank.missing_helper': 'No payout account yet',
    'profile.auto_reward.pin.title': 'Enter 6-digit PIN',
    'profile.auto_reward.pin.subtitle':
        'To confirm automatic reward claim settings',
    'profile.menu.line_notifications': 'LINE notifications',
    'profile.line_notifications.hero.title': 'Get every transaction update',
    'profile.line_notifications.hero.subtitle':
        'Topups, lottery purchases, activity updates, and reward payout status from this store.',
    'profile.line_notifications.store_unavailable.title':
        'This store has not enabled LINE OA yet',
    'profile.line_notifications.store_unavailable.message':
        'Once the store completes setup, you can connect LINE and receive notifications.',
    'profile.line_notifications.reconnect': 'Reconnect LINE',
    'profile.line_notifications.connect': 'Connect LINE',
    'profile.line_notifications.add_friend': 'Add LINE OA friend',
    'profile.line_notifications.disconnect': 'Disconnect',
    'profile.line_notifications.connect_failed':
        'Could not connect LINE. Please try again.',
    'profile.line_notifications.save_failed':
        'Could not save notification settings.',
    'profile.line_notifications.disconnected': 'LINE has been disconnected.',
    'profile.line_notifications.disconnect_failed':
        'Could not disconnect LINE.',
    'profile.line_notifications.missing_url': 'Connection URL was not found.',
    'profile.line_notifications.connected_title': 'LINE connected',
    'profile.line_notifications.not_connected_title': 'LINE not connected',
    'profile.line_notifications.connect_once':
        'Connect once to receive LINE notifications instantly.',
    'profile.line_notifications.ready': 'Ready',
    'profile.line_notifications.not_linked': 'Not linked',
    'profile.line_notifications.status.notification': 'Notifications',
    'profile.line_notifications.status.notification_on': 'On',
    'profile.line_notifications.status.notification_off': 'Off',
    'profile.line_notifications.status.friend': 'OA friend',
    'profile.line_notifications.status.friend_added': 'Added',
    'profile.line_notifications.status.friend_missing': 'Not added',
    'profile.line_notifications.toggle.title': 'Receive LINE notifications',
    'profile.line_notifications.toggle.subtitle':
        'Keep this on for automatic updates about important requests.',
    'profile.line_notifications.events.title': 'Notifications we will send',
    'profile.line_notifications.events.subtitle':
        'Messages will be sent from this store’s LINE OA.',
    'profile.line_notifications.events.topup':
        'Topups and topup status updates',
    'profile.line_notifications.events.order':
        'Lottery purchases and order confirmations',
    'profile.line_notifications.events.activity':
        'Store activity participation',
    'profile.line_notifications.events.reward':
        'Reward claims and payout status',
    'profile.line_notifications.load_failed': 'Could not load LINE settings.',
    'profile.menu.biometrics': 'Face ID / Biometric',
    'profile.biometric.enabled': 'Biometric unlock is enabled for this device.',
    'profile.biometric.enable_failed':
        'Could not enable biometric unlock. Please check your PIN or try again.',
    'profile.biometric.revoke_dialog.title': 'Revoke this device?',
    'profile.biometric.revoke_dialog.message':
        'Device "{device}" will no longer be able to use Face ID / Biometric instead of PIN.',
    'profile.biometric.revoked': 'Device revoked.',
    'profile.biometric.revoke_failed': 'Could not revoke this device.',
    'profile.biometric.pin_dialog.title': 'Confirm 6-digit PIN',
    'profile.biometric.setup_reason':
        'Authenticate to enable biometric unlock on this device',
    'profile.biometric.device_name.ios': 'This iPhone / iPad',
    'profile.biometric.device_name.android': 'This Android device',
    'profile.biometric.device_name.fallback': 'This device',
    'profile.biometric.intro.title': 'Use Face ID / Biometric instead of PIN',
    'profile.biometric.intro.subtitle':
        'Confirm your 6-digit PIN once before enabling. You can revoke devices anytime.',
    'profile.biometric.enable.unavailable_title':
        'Biometric unlock is not available on this device',
    'profile.biometric.enable.title': 'Enable on this device',
    'profile.biometric.enable.unavailable_message':
        'Make sure Face ID, Touch ID, or fingerprint unlock is set up on this device.',
    'profile.biometric.enable.message':
        'After enabling, PIN confirmation screens can use biometric unlock to create a short-lived identity token.',
    'profile.biometric.enable.saving': 'Saving...',
    'profile.biometric.enable.button': 'Enable biometric',
    'profile.biometric.empty.title': 'No biometric devices yet',
    'profile.biometric.empty.message':
        'Enable this device for faster verification while keeping PIN as recovery.',
    'profile.biometric.active_devices': 'Active devices',
    'profile.biometric.no_active_devices': 'No active devices',
    'profile.biometric.revoked_devices': 'Revoked device history',
    'profile.biometric.status.active': 'Active',
    'profile.biometric.status.revoked': 'Revoked',
    'profile.biometric.status.current_device': 'This device',
    'profile.biometric.never_used': 'Never used',
    'profile.biometric.meta.registered': 'Registered',
    'profile.biometric.meta.last_used': 'Last used',
    'profile.biometric.revoke_device': 'Revoke this device',
    'profile.biometric.load_failed': 'Could not load biometric devices.',
    'profile.menu.purchase_history': 'Purchase history',
    'profile.menu.news_all': 'All news',
    'profile.menu.terms': 'Terms and conditions',
    'profile.menu.privacy_policy': 'Privacy policy',
    'profile.menu.account_deletion': 'Delete account',
    'profile.logout': 'Sign out',
    'account_deletion.title': 'Delete account',
    'account_deletion.hero.title': 'Account deletion request',
    'account_deletion.hero.subtitle':
        'Request deletion of your account and personal information.',
    'account_deletion.before.title': 'Before you request deletion',
    'account_deletion.before.body':
        'After the request is reviewed, this account will no longer be able to sign in. Some transaction records may still need to be retained as required by law.',
    'account_deletion.request.title': 'Request channel',
    'account_deletion.request.body':
        'You can start an account deletion request through the channel configured by this store. The system will use your current account information for identity verification before processing.',
    'account_deletion.open_request': 'Request account deletion',
    'account_deletion.contact_support': 'Contact store',
    'account_deletion.contact_support_online': 'Contact store online',
    'account_deletion.contact_support_with_phone': 'Contact store {phone}',
    'account_deletion.contact_support_with_email': 'Contact store {email}',
    'account_deletion.no_online_request':
        'This store has not configured an online account deletion link yet. Please contact the store to request deletion.',
    'account_deletion.launch_failed': 'Could not open the request link.',
    'wallet.title': 'My Wallet',
    'wallet.balance.loading': 'Loading...',
    'wallet.recent_ledger': 'Recent transactions',
    'wallet.recent_ledger.subtitle': 'Topups, payments, and reward credits',
    'wallet.refresh_tooltip': 'Refresh transactions',
    'wallet.ledger.loading': 'Loading transactions...',
    'wallet.ledger.load_failed': 'Could not load transaction history',
    'wallet.ledger.load_failed_message': 'Please try again.',
    'wallet.empty_ledger.title': 'No wallet transactions yet',
    'wallet.empty_ledger.subtitle':
        'Topups, payments, and reward credits will appear here.',
    'wallet.balance_after': 'Balance {amount}',
    'wallet.ledger.topup': 'G-Wallet topup',
    'wallet.ledger.order': 'Digital lottery payment',
    'wallet.ledger.reward_claim': 'Lottery reward payout',
    'wallet.ledger.activity_reward': 'Activity reward',
    'wallet.ledger.activity_cashback': 'Activity cashback',
    'wallet.ledger.order_refund': 'Wallet refund',
    'wallet.ledger.debit': 'Wallet debit',
    'wallet.ledger.credit': 'Wallet credit',
    'wallet.ledger.generic': 'Wallet transaction',
    'wallet.ledger.reference': 'Reference {reference}',
    'wallet.ledger.success': 'Completed transaction',
    'topup.title': 'Top up G-Wallet',
    'topup.loading': 'Loading topup channels',
    'topup.loading_message':
        'Please wait while we prepare the topup information.',
    'topup.load_failed': 'Could not load topup information',
    'topup.load_failed_message': 'Please try again.',
    'topup.header.title': 'Top up G-Wallet',
    'topup.header.subtitle': 'Choose a payment channel and create a topup',
    'topup.history_tooltip': 'View topup history',
    'topup.waiting.title': 'Unfinished topup',
    'topup.waiting.amount_label': 'Topup amount',
    'topup.waiting.qr_title': 'Scan QR Code to pay',
    'topup.waiting.slip_title': 'Payment slip',
    'topup.waiting.slip_pending': 'Waiting slip',
    'topup.waiting.slip_sent': 'Sent',
    'topup.waiting.slip_pending_description':
        'Upload the slip after paying this request.',
    'topup.waiting.slip_sent_description':
        'Slip received. You can upload a new one if it needs correction.',
    'topup.reference': 'Request #{reference}',
    'topup.qr_slip_instruction':
        'After payment, attach a slip so the store can verify it.',
    'topup.open_payment': 'Open payment page',
    'topup.open_payment_failed': 'Could not open payment page.',
    'topup.needs_slip': 'This request is waiting for a slip or review.',
    'topup.upload_slip': 'Attach payment slip',
    'topup.upload_new_slip': 'Upload a new slip',
    'topup.uploading_slip': 'Uploading...',
    'topup.cancel_waiting': 'Cancel this topup request',
    'topup.cancel_confirm.title': 'Cancel this topup request?',
    'topup.cancel_confirm.message':
        'Request #{reference} will be cancelled, and you can create a new topup request immediately.',
    'topup.cancel_confirm.amount_label': 'Topup amount',
    'topup.cancel_confirm.keep': 'Keep request',
    'topup.cancel_confirm.confirm': 'Confirm cancel',
    'topup.cancel_confirm.cancelling': 'Cancelling...',
    'topup.choose_channel': 'Choose a topup channel',
    'topup.blocking_waiting.title': 'Unfinished topup request',
    'topup.blocking_waiting.message':
        'Please pay or cancel the current request before creating a new one.',
    'topup.amount_label': 'Topup amount',
    'topup.baht_suffix': 'THB',
    'topup.submit.qr': 'Create QR Code',
    'topup.submit.credit_qr': 'Create QR Code',
    'topup.submit.bank_transfer': 'Confirm payment',
    'topup.submit.creating_qr': 'Creating QR...',
    'topup.submit.submitting_bank_transfer': 'Submitting slip...',
    'topup.bank_slip.title': 'Transfer slip',
    'topup.bank_slip.description':
        'Attach the payment slip and send it with this topup request for admin review.',
    'topup.bank_slip.attach': 'Attach slip',
    'topup.bank_slip.change': 'Change slip',
    'topup.bank_slip.remove': 'Remove slip',
    'topup.bank_slip.file_label': 'Slip file',
    'topup.bank_slip.transfer_at': 'Transfer time',
    'topup.bank_slip.transfer_at_unset': 'Choose transfer time',
    'topup.bank_slip.required':
        'Please attach a payment slip before sending this request for review.',
    'topup.bank_transfer_submitted':
        'Slip sent successfully. Please wait for admin review.',
    'topup.deferred_slip.qr':
        'Create a QR Code, then attach a slip after payment so the store can verify it.',
    'topup.deferred_slip.credit':
        'This channel shows a QR Code and lets you attach a slip after payment.',
    'topup.channel.qr.label': 'QR Code',
    'topup.channel.qr.description':
        'Create a QR Code and attach a slip after payment.',
    'topup.channel.credit.label': 'Credit Card QR',
    'topup.channel.credit.description':
        'Create a QR Code for credit payment channels.',
    'topup.channel.bank.label': 'Bank transfer',
    'topup.channel.bank.description':
        'Transfer to the store account and attach a slip afterward.',
    'topup.channel.disabled': 'Temporarily unavailable',
    'topup.bank_account_fallback': 'Receiving account',
    'topup.status.pending_payment': 'Pending payment',
    'topup.status.pending_review': 'Pending review',
    'topup.status.approved': 'Approved',
    'topup.status.rejected': 'Rejected',
    'topup.status.cancelled': 'Cancelled',
    'topup.status.expired': 'Expired',
    'topup.status.unknown': 'Processing',
    'topup.error.amount_required': 'Please enter a topup amount.',
    'topup.error.minimum_amount': '{channel} minimum is {amount}.',
    'topup.minimum_hint': 'Minimum {amount}',
    'topup.created': 'Topup request created.',
    'topup.create_failed': 'Could not create topup request. Please try again.',
    'topup.cancelled': 'Topup request cancelled.',
    'topup.cancel_failed': 'Could not cancel this request.',
    'topup.slip_too_large': 'Slip file must not exceed 5 MB.',
    'topup.slip_uploaded': 'Slip uploaded successfully.',
    'topup.slip_upload_failed': 'Could not upload slip. Please try again.',
    'topup.history.title': 'Topup history',
    'topup.history.loading': 'Loading data...',
    'topup.history.load_failed': 'Could not load topup history.',
    'topup.history.header.title': 'Recent topups',
    'topup.history.header.subtitle': 'Track G-Wallet topup request status.',
    'topup.history.item_title': 'G-Wallet topup',
    'topup.history.reference': 'Request #{reference}\n{channel} • {date}',
    'topup.history.bonus': 'Bonus {amount}',
    'topup.history.empty.title': 'No topup history yet',
    'topup.history.empty.subtitle':
        'Successful topups will appear on this page.',
    'reward_claims.title': 'Reward claim history',
    'reward_claims.header.title': 'Digital lottery reward claims',
    'reward_claims.header.subtitle': 'Track reward claim status',
    'reward_claims.tickets_tooltip': 'View tickets',
    'reward_claims.prize_title': 'Lottery reward',
    'reward_claims.loading': 'Loading reward claim history...',
    'reward_claims.load_failed': 'Could not load reward claim history.',
    'reward_claims.load_more_failed': 'Could not load more items.',
    'reward_claims.loading_more': 'Loading...',
    'reward_claims.load_more': 'Load more',
    'reward_claims.empty.title': 'No reward claims yet',
    'reward_claims.empty.subtitle': 'Submitted reward claims will appear here.',
    'reward_claims.view_winning_tickets': 'View winning tickets',
    'reward_claims.detail.title': 'Reward claim details',
    'reward_claims.detail.loading': 'Loading reward claim details...',
    'reward_claims.detail.load_failed': 'Could not load reward claim details.',
    'reward_claims.detail.method': 'Claim method',
    'reward_claims.detail.manual_method': 'Manual reward claim',
    'reward_claims.detail.payout_channel': 'Reward claim payout channel',
    'reward_claims.detail.status': 'Status',
    'reward_claims.detail.draw_date': 'Lottery draw date',
    'reward_claims.detail.tax': 'Withholding tax (0.5%)',
    'reward_claims.detail.fee': 'Fee (1%)',
    'reward_claims.detail.waived': 'Waived {amount}',
    'reward_claims.detail.zero_baht': '0 THB',
    'reward_claims.detail.bank_fallback': 'Bank account',
    'reward_claims.detail.wallet_fallback': 'G-Wallet',
    'reward_claims.customer_fallback': 'Customer',
    'reward_claims.payout.bank_prefix': 'ธนาคาร',
    'reward_claims.payout.bank': 'Receive via {bank} account',
    'reward_claims.payout.wallet': 'Receive in {wallet}',
    'reward_claims.prize.more': '{prize} and {count} more prizes',
    'reward_claims.prize.first_prize': 'First prize',
    'reward_claims.prize.near_first_prize': 'Adjacent first prize',
    'reward_claims.prize.second_prize': 'Second prize',
    'reward_claims.prize.third_prize': 'Third prize',
    'reward_claims.prize.fourth_prize': 'Fourth prize',
    'reward_claims.prize.fifth_prize': 'Fifth prize',
    'reward_claims.prize.front3': 'Front 3 digits',
    'reward_claims.prize.back3': 'Last 3 digits',
    'reward_claims.prize.back2': 'Last 2 digits',
    'reward_claims.prize.fallback': 'Winning prize',
    'reward_claims.status.paid': 'Paid successfully',
    'reward_claims.status.rejected': 'Claim failed',
    'reward_claims.status.cancelled': 'Cancelled',
    'reward_claims.status.approved': 'Approved, awaiting transfer',
    'reward_claims.status.submitted': 'Transfer pending',
    'reward_claims.note.paid': 'The reward has been transferred successfully.',
    'reward_claims.note.rejected':
        'This reward claim failed. Please review the details or contact support.',
    'reward_claims.note.cancelled':
        'This reward claim was cancelled. Please review the details or contact support.',
    'reward_claims.note.approved':
        'This reward claim was approved and transfer is in progress.',
    'reward_claims.note.submitted':
        'The reward will reach the recipient account within 2 hours after the request succeeds.',
    'reward_claims.detail.empty': 'Reward claim was not found',
    'activity_claims.title': 'Activity reward claim history',
    'activity_claims.header.title': 'Activity reward payouts',
    'activity_claims.header.subtitle':
        'Track cashback and activity reward payout status.',
    'activity_claims.activities_tooltip': 'View activities',
    'activity_claims.prize_title': 'Activity reward',
    'activity_claims.loading': 'Loading activity reward claim history...',
    'activity_claims.load_failed':
        'Could not load activity reward claim history.',
    'activity_claims.load_more_failed': 'Could not load more items.',
    'activity_claims.empty.title': 'No activity reward claims yet',
    'activity_claims.empty.subtitle':
        'Cashback and activity reward claims will appear here.',
    'activity_claims.view_activities': 'View activities',
    'activity_claims.detail.title': 'Activity claim details',
    'activity_claims.detail.loading': 'Loading activity claim details...',
    'activity_claims.detail.load_failed':
        'Could not load activity claim details.',
    'activity_claims.detail.reward_title': 'Activity reward',
    'activity_claims.activity_fallback': 'Activity',
    'activity_claims.customer_fallback': 'Customer',
    'activity_claims.detail.recipient': 'Recipient',
    'activity_claims.detail.payout_channel': 'Payout channel',
    'activity_claims.detail.payout_method': 'Claim method',
    'activity_claims.detail.status': 'Status',
    'activity_claims.detail.activity': 'Activity',
    'activity_claims.detail.reward_type': 'Reward type',
    'activity_claims.detail.reference': 'Reference',
    'activity_claims.detail.submitted_at': 'Submitted at',
    'activity_claims.detail.paid_at': 'Paid at',
    'activity_claims.detail.reviewed_at': 'Reviewed at',
    'activity_claims.detail.customer_note': 'Customer note',
    'activity_claims.detail.admin_note': 'Reviewer note',
    'activity_claims.payout.bank_transfer': 'Bank transfer',
    'activity_claims.payout.wallet_credit': 'G-Wallet credit',
    'activity_claims.payout.bank_fallback': 'Bank account',
    'activity_claims.payout.wallet_fallback': 'G-Wallet',
    'activity_claims.payout.bank_prefix': 'ธนาคาร',
    'activity_claims.payout.bank_summary': 'Receive via {bank}',
    'activity_claims.payout.wallet_summary': 'Receive in {wallet}',
    'activity_claims.detail.amount': 'Activity reward amount',
    'activity_claims.detail.net_amount': 'Net amount',
    'activity_claims.detail.empty': 'Activity claim was not found',
    'activity_claims.status.paid': 'Paid successfully',
    'activity_claims.status.rejected': 'Claim failed',
    'activity_claims.status.cancelled': 'Cancelled',
    'activity_claims.status.approved': 'Approved, awaiting transfer',
    'activity_claims.status.submitted': 'Transfer pending',
    'activity_claims.note.paid':
        'The activity reward has been transferred successfully.',
    'activity_claims.note.rejected':
        'This activity claim failed. Please review the details or contact support.',
    'activity_claims.note.cancelled':
        'This activity claim was cancelled. Please review the details or contact support.',
    'activity_claims.note.approved':
        'This activity claim was approved and transfer is in progress.',
    'activity_claims.note.submitted':
        '{reviewer} will review and process your activity reward payout.',
    'activity_claims.reviewer_fallback': 'The service provider',
    'activity_claims.reward.cashback': 'Activity cashback',
    'activity_claims.reward.first_prize_last2':
        'Lucky board reward: 1st prize last 2 digits',
    'activity_claims.reward.first_prize_last3':
        'Lucky board reward: 1st prize last 3 digits',
    'activity_claims.reward.last2': 'Lucky board reward: last 2 digits',
    'activity_claims.reward.fallback': 'Activity reward',
    'activities.history_button': 'View last draw',
    'activities.history_title': 'Past draw activities',
    'activities.history_hint': 'View activities from previous draws',
    'activities.history_select_label': 'Select past draw',
    'activities.history_no_games': 'No past activities',
    'activities.back_to_current': 'Back to current draw activities',
    'activities.loading': 'Loading activities',
    'activities.history_loading': 'Loading past activities',
    'activities.load_failed': 'Could not load activities.',
    'activities.empty.title': 'No activities in this draw yet',
    'activities.empty.message':
        'When this store creates activities for the current draw, details will appear here.',
    'activities.history_empty.title': 'No past activities yet',
    'activities.history_empty.message':
        'Past draw activities will be available from this page.',
    'activities.fallback_name': 'Special activity',
    'activities.type.cashback': 'Cashback',
    'activities.type.lucky_board': 'Lucky board',
    'activities.prediction.first_prize_last2': '1st prize last 2 digits',
    'activities.prediction.first_prize_last3': '1st prize last 3 digits',
    'activities.prediction.last2': 'Last 2 digits',
    'activities.prediction.fallback': 'Lucky board',
    'activities.condition.fallback': 'View activity details and conditions',
    'activities.condition.min_tickets': 'Buy {count} ticket(s) to join',
    'activities.condition.min_baht': 'Spend {amount} to join',
    'activities.meta.cashback_estimate': 'Estimated cashback {amount}',
    'activities.meta.cashback_pending':
        'Cashback eligibility checked after result announcement',
    'activities.meta.entry_closed': 'Entry period has ended',
    'activities.meta.guest': 'Log in to check rights',
    'activities.meta.pin': 'Confirm PIN to check rights',
    'activities.meta.rights_used': '0 rights available (used)',
    'activities.meta.no_rights': 'No rights yet (0 rights)',
    'activities.meta.deadline': 'Available until {date}',
    'activities.meta.deadline_fallback': 'Closes 30 minutes after sales close',
    'activities.meta.rights': '{count} right(s) available',
    'activities.meta.remaining_numbers': '{count} number(s) left',
    'activity_detail.title': 'Activity details',
    'activity_detail.loading': 'Loading activity details...',
    'activity_detail.load_failed': 'Could not load activity details.',
    'activity_detail.has_right': 'Eligible to join',
    'activity_detail.entry_closed': 'Entry closed',
    'activity_detail.game_fallback': 'Activity draw',
    'activity_detail.result_time': 'Activity result {time}',
    'activity_detail.confirm_number.eyebrow': 'Confirm lucky number',
    'activity_detail.confirm_number.title': 'Choose this number?',
    'activity_detail.confirm_number.message':
        'This uses 1 right for {prediction}, and this number cannot be selected again.',
    'activity_detail.confirm_number.submit': 'Confirm number',
    'activity_detail.entry.submit_success': 'Number submitted.',
    'activity_detail.entry.closed': 'This activity is closed for entries.',
    'activity_detail.entry.submit_failed':
        'Could not submit number. Please check your rights and try again.',
    'activity_detail.status.cashback_title': 'Cashback eligibility',
    'activity_detail.status.number_title': 'Numbers left to choose',
    'activity_detail.status.calculating': 'Calculating',
    'activity_detail.status.remaining_numbers': '{count} numbers',
    'activity_detail.status.cashback_subtitle':
        'The system will check eligibility after results are announced.',
    'activity_detail.status.board_closed':
        'This activity no longer accepts numbers.',
    'activity_detail.status.board_available':
        'Choose numbers using rights earned from purchases in this draw.',
    'activity_detail.cashback.title': 'Cashback eligibility',
    'activity_detail.cashback.progress_eligible': 'Purchase condition met',
    'activity_detail.cashback.progress_pending':
        'Waiting for purchase condition',
    'activity_detail.cashback.eligible_title':
        'Your purchases meet the condition',
    'activity_detail.cashback.pending_title': 'Purchase condition not met yet',
    'activity_detail.cashback.eligible_description':
        'The system will check eligibility at {resultTime}. Customers must not win the lottery or lucky-board reward.',
    'activity_detail.cashback.pending_description':
        'Buy at least {minimum} in this draw to wait for cashback calculation at {resultTime}.',
    'activity_detail.cashback.reward_fallback':
        'Cashback based on activity conditions',
    'activity_detail.cashback.expected_label': 'Expected cashback',
    'activity_detail.cashback.expected_hint':
        'The system will summarize eligibility again at {resultTime}',
    'activity_detail.cashback.purchase_amount': 'Draw purchase amount',
    'activity_detail.cashback.ticket_count': 'Ticket count',
    'activity_detail.cashback.minimum': 'Minimum condition',
    'activity_detail.cashback.no_minimum': 'No minimum',
    'activity_detail.cashback.tickets': '{count} ticket(s)',
    'activity_detail.cashback.detail.reward_type': 'Cashback type',
    'activity_detail.cashback.detail.main_condition': 'Main condition',
    'activity_detail.cashback.detail.main_condition_value':
        'No lottery prize and no lucky-board prize',
    'activity_detail.cashback.detail.calculation_time': 'Calculation time',
    'activity_detail.cashback.detail.payout': 'Payout',
    'activity_detail.cashback.detail.payout_value':
        'Claim from activity rewards or enable automatic reward claim',
    'activity_detail.cashback.manual_claim.title': 'Claim manually',
    'activity_detail.cashback.manual_claim.ready': 'Cashback is ready to claim',
    'activity_detail.cashback.manual_claim.pending':
        'A claim button will appear after calculation',
    'activity_detail.cashback.auto_reward.title': 'Automatic claim',
    'activity_detail.cashback.auto_reward.subtitle':
        'Set up automatic payout channel',
    'activity_detail.cashback.claim_not_ready.title': 'No cashback ready yet',
    'activity_detail.cashback.claim_not_ready.message':
        'Cashback will appear after eligibility has been calculated.',
    'activity_detail.cashback.result_time_fallback': '17:00 on result day',
    'activity_detail.result.title': 'Activity result',
    'activity_detail.result.winning_number': 'Winning number for {prediction}',
    'activity_detail.result.customer_won': 'You won activity reward {amount}',
    'activity_detail.result.customer_lost': 'You did not win this activity.',
    'activity_detail.result.customer_winning_numbers': 'Your winning number(s)',
    'activity_detail.result.winner_count': '{count} winner(s)',
    'activity_detail.award.claim_button': 'Claim',
    'activity_detail.award.ready': 'Ready to claim',
    'activity_detail.award.claimed': 'Claim request submitted',
    'activity_detail.award.processing': 'Processing',
    'activity_detail.award_status.title': 'Activity rewards',
    'activity_detail.award_status.count': '{count} item(s)',
    'activity_detail.award_status.login_count': 'Sign in to view status',
    'activity_detail.award_status.not_joined_count': 'Not joined',
    'activity_detail.award_status.no_reward_count': 'No rewards yet',
    'activity_detail.award_status.pending_count': 'Waiting for result',
    'activity_detail.award_status.missed_title':
        'You did not receive this activity reward',
    'activity_detail.award_status.not_joined_title':
        'You have not joined this activity yet',
    'activity_detail.award_status.pending_title': 'Waiting for activity result',
    'activity_detail.award_status.login_title': 'Sign in to view your rewards',
    'activity_detail.award_status.no_reward_title': 'No activity rewards yet',
    'activity_detail.award_status.missed_message':
        'Your selected numbers did not match this activity result.',
    'activity_detail.award_status.not_joined_message':
        'Use your number-selection rights before result time to join.',
    'activity_detail.award_status.pending_message':
        'Rewards will appear after the activity result is announced.',
    'activity_detail.award_status.login_message':
        'Sign in to see whether you received a reward or cashback from this activity.',
    'activity_detail.award_status.no_reward_message':
        'The result has been announced, but no claimable reward is available for this activity.',
    'activity_detail.condition.title': 'Activity conditions',
    'activity_detail.rights.title': 'Your rights',
    'activity_detail.rights.earned': 'Earned',
    'activity_detail.rights.used': 'Used',
    'activity_detail.rights.remaining': 'Remaining',
    'activity_detail.rights.ticket_summary':
        'Purchased {total} ticket(s) · {consumed} ticket(s) already used for rights',
    'activity_detail.rights.deadline': 'Entry closes {date}',
    'activity_detail.selected_numbers.title': 'Selected numbers',
    'activity_detail.board.title': '{prediction} board',
    'activity_detail.board.summary':
        '{range} · {remaining} of {total} numbers left',
    'activity_detail.board.can_select':
        'Tap a number to confirm. Each number uses 1 right.',
    'activity_detail.board.closed': 'This activity is closed for entries.',
    'activity_detail.board.no_rights': 'No remaining rights to choose numbers.',
    'activity_detail.board.reserved_hint': 'Red numbers are already selected',
    'activity_detail.board.reserved_short': 'Taken',
    'activity_detail.board.entry_closed_hint': 'Entry period ended',
    'activity_detail.login_to_join.title':
        'Sign in to view rights and choose numbers',
    'activity_detail.login_to_join.button': 'Sign in',
    'activity_detail.claim_sheet.title': 'Claim activity reward',
    'activity_detail.claim_sheet.eyebrow': 'Activity payout',
    'activity_detail.claim_sheet.available_amount': 'Available amount',
    'activity_detail.claim_sheet.wallet.title': 'Receive to G-Wallet',
    'activity_detail.claim_sheet.wallet.account_title': 'G Wallet x {suffix}',
    'activity_detail.claim_sheet.wallet.subtitle':
        'Funds will be credited after {reviewer} approval.',
    'activity_detail.claim_sheet.bank.title': 'Transfer to bank account',
    'activity_detail.claim_sheet.bank.ready':
        'Receive funds in your saved payout account.',
    'activity_detail.claim_sheet.bank.missing': 'No payout account set',
    'activity_detail.claim_sheet.bank.recipient_fallback': 'Recipient',
    'activity_detail.claim_sheet.setup_bank': 'Set payout account',
    'activity_detail.claim_sheet.confirm_pin': 'Confirm with PIN',
    'activity_detail.claim_sheet.pin.title': 'Enter 6-digit PIN',
    'activity_detail.claim_sheet.pin.subtitle': 'To claim activity reward',
    'activity_detail.claim_sheet.pin.progress': '{count}/6 digits entered',
    'activity_detail.claim_sheet.profile_loading':
        'Loading payout information...',
    'activity_detail.claim_sheet.profile_load_failed':
        'Could not load payout information. Please try again.',
    'activity_detail.claim_sheet.bank_required':
        'Please set a payout account first.',
    'activity_detail.claim_sheet.pin_invalid':
        'PIN is incorrect. Please try again.',
    'activity_detail.claim_sheet.pin_locked':
        'Too many incorrect PIN attempts. Please wait.',
    'activity_detail.claim_sheet.pin_setup_required':
        'Please set up your PIN before continuing.',
    'activity_detail.claim_sheet.submit_failed':
        'Could not claim activity reward. Please try again.',
    'activity_detail.claim_sheet.biometric_unavailable':
        'Biometric verification is unavailable.',
    'activity_detail.claim_sheet.biometric_failed':
        'Biometric verification failed. Please use PIN.',
    'activity_detail.claim_sheet.biometric_button': 'Use Face ID / Biometric',
    'activity_detail.missing': 'Activity was not found',
    'activity_detail.missing.title': 'Activity not found',
    'activity_detail.missing.message':
        'This activity may be disabled or no longer visible.',
    'activity_detail.missing.back_to_activities': 'Back to activities',
    'purchase_history.title': 'Purchase history',
    'purchase_history.header.title': 'Digital six-digit lottery purchases',
    'purchase_history.header.subtitle': 'View past purchases and receipts.',
    'purchase_history.buy_tooltip': 'Buy lottery',
    'purchase_history.year': '{year}',
    'purchase_history.order_title': 'Lottery purchase',
    'purchase_history.digital_ticket': 'Digital lottery',
    'purchase_history.draw_date': 'Draw date {date}',
    'purchase_history.ticket_count': '{count} ticket(s)',
    'purchase_history.load_failed': 'Could not load purchase history.',
    'purchase_history.load_more_failed': 'Could not load more items.',
    'purchase_history.empty.title': 'No lottery purchase history yet',
    'purchase_history.empty.subtitle':
        'Successful lottery purchases will appear here.',
    'purchase_history.buy_button': 'Buy lottery',
    'purchase_history.detail.title': 'Purchase details',
    'purchase_history.detail.receipt_title':
        'Digital six-digit lottery purchase',
    'purchase_history.detail.receipt_subtitle':
        'You can view your tickets from My Tickets.',
    'purchase_history.detail.ticket_count': 'Ticket quantity',
    'purchase_history.detail.draw_date': 'Lottery draw date',
    'purchase_history.detail.payee': 'Paid to',
    'purchase_history.detail.payment_channel': 'Payment channel',
    'purchase_history.detail.total': 'Total paid',
    'purchase_history.detail.transaction_at': 'Transaction date {date}',
    'purchase_history.detail.reference': 'Reference {reference}',
    'purchase_history.detail.reference_label': 'Reference',
    'purchase_history.detail.ticket_list': 'Lottery numbers in this order',
    'purchase_history.detail.empty': 'Purchase order was not found',
    'purchase_history.store_fallback': 'Lottery store',
    'lottery.tabs.all': 'All tickets',
    'lottery.tabs.stores': 'Stores',
    'stores.title': 'Stores',
    'stores.search_label': 'Search stores',
    'stores.recommended.title': 'Recommended lottery stores',
    'stores.load_failed.title': 'Could not load stores',
    'stores.load_failed.message': 'Please try again.',
    'stores.empty.title': 'No stores found',
    'stores.empty.message': 'Try another keyword or check back later.',
    'stores.fallback_store_name': 'Lottery store',
    'stores.code': 'Store code {code}',
    'stores.lotteries.title': 'Digital six-digit lottery store',
    'stores.lotteries.subtitle': 'Search lottery numbers in this store',
    'stores.lotteries.load_failed.title': 'Could not load lottery numbers',
    'stores.lotteries.load_failed.message': 'Please try again.',
    'stores.lotteries.empty.title': 'No tickets available',
    'stores.lotteries.empty.message':
        'This store has no tickets available for the current draw.',
    'stores.ticket.available': 'Available',
    'stores.ticket.sold_out': 'Sold out',
    'affiliate.title': 'Affiliate',
    'affiliate.back_tooltip': 'Back',
    'affiliate.refresh_tooltip': 'Refresh',
    'affiliate.load_failed': 'Could not load affiliate information.',
    'affiliate.register.store_name_required':
        'Please enter a store name before applying.',
    'affiliate.register.success': 'Affiliate application completed.',
    'affiliate.register.failed': 'Could not apply for affiliate.',
    'affiliate.withdraw.minimum': 'Minimum withdrawal {amount}',
    'affiliate.withdraw.exceeds':
        'Withdrawal amount exceeds available balance.',
    'affiliate.withdraw.bank_required':
        'Please save a payout account before withdrawing.',
    'affiliate.withdraw.success': 'Withdrawal request submitted.',
    'affiliate.withdraw.failed': 'Could not withdraw. Please try again.',
    'affiliate.link_copied': 'Referral link copied.',
    'affiliate.pin.invalid': 'PIN is incorrect. Please try again.',
    'affiliate.pin.locked':
        'Too many incorrect PIN attempts. Please wait and try again.',
    'affiliate.pin.setup_required':
        'Please set up PIN before opening Affiliate.',
    'affiliate.pin.failed': 'Could not verify PIN. Please try again.',
    'affiliate.pin.title': 'Enter 6-digit PIN',
    'affiliate.pin.subtitle': 'To open Affiliate',
    'affiliate.hero.fallback': 'Affiliate',
    'affiliate.hero.subtitle': 'Refer others and earn sales rewards.',
    'affiliate.store_summary.label': 'Your store name',
    'affiliate.store_summary.description':
        'Customers who enter through your referral link will see this name.',
    'affiliate.register.title': 'Start as an affiliate',
    'affiliate.register.description':
        'Enter the store name customers will see. The system will create your referral code immediately.',
    'affiliate.register.store_label': 'Store name',
    'affiliate.register.store_hint': 'Example: Lucky Online Shop',
    'affiliate.register.button': 'Apply as affiliate',
    'affiliate.stats.available.title': 'Available',
    'affiliate.stats.available.subtitle': 'Ready to withdraw',
    'affiliate.stats.approved.title': 'Approved',
    'affiliate.stats.approved.subtitle': 'Commission',
    'affiliate.stats.pending.title': 'Pending',
    'affiliate.stats.pending.subtitle': 'Awaiting approval',
    'affiliate.stats.converted.title': 'Converted',
    'affiliate.stats.converted.subtitle': 'Orders',
    'affiliate.stats.visitors.title': 'Link clicks',
    'affiliate.stats.visitors.subtitle': 'Visitors',
    'affiliate.stats.registered.title': 'Registered',
    'affiliate.stats.registered.subtitle': 'Accounts',
    'affiliate.tab.overview': 'Overview',
    'affiliate.tab.withdraw': 'Withdraw',
    'affiliate.tab.commissions': 'Commissions',
    'affiliate.tab.payouts': 'History',
    'affiliate.referral.title': 'Referral link',
    'affiliate.referral.description':
        'Share this link for friends to sign up or buy through your store.',
    'affiliate.referral.empty': 'No referral link yet',
    'affiliate.referral.copy_tooltip': 'Copy link',
    'affiliate.bank.title': 'Payout account',
    'affiliate.bank.description': 'Uses the same account as reward payouts.',
    'affiliate.bank.empty': 'No payout account saved',
    'affiliate.edit': 'Edit',
    'affiliate.withdraw.title': 'Request withdrawal',
    'affiliate.withdraw.description':
        'Withdraw up to your approved available balance.',
    'affiliate.withdraw.amount_label': 'Amount (THB)',
    'affiliate.withdraw.method_label': 'Withdrawal channel',
    'affiliate.withdraw.bank_transfer': 'Transfer to payout account',
    'affiliate.withdraw.bank_description':
        'This account will also be used for commission withdrawals.',
    'affiliate.withdraw.wallet_credit': 'Credit to wallet',
    'affiliate.withdraw.bank_missing':
        'No payout account yet. Please save one before withdrawing.',
    'affiliate.withdraw.submit': 'Submit withdrawal request',
    'affiliate.commissions.empty': 'No commission records yet',
    'affiliate.payouts.empty': 'No withdrawal records yet',
    'affiliate.payout_method.wallet_credit': 'Credit to wallet',
    'affiliate.payout_method.bank_transfer': 'Bank transfer',
    'affiliate.status.active': 'Active',
    'affiliate.status.calculated': 'Awaiting approval',
    'affiliate.status.approved': 'Approved',
    'affiliate.status.pending': 'Pending',
    'affiliate.status.paid': 'Paid',
    'affiliate.status.reversed': 'Reversed',
    'affiliate.status.rejected': 'Rejected',
    'tickets.title': 'My Tickets',
    'tickets.loading': 'Loading tickets...',
    'tickets.load_failed': 'Could not load tickets.',
    'tickets.history_tooltip': 'Ticket history',
    'tickets.current_draw.title': 'Current draw',
    'tickets.current_draw.subtitle':
        'Purchased tickets and pending reward claims are grouped by status.',
    'tickets.search_numbers': 'Search lottery numbers',
    'tickets.search.placeholder': 'Search numbers in My Tickets',
    'tickets.search.submit': 'Search',
    'tickets.search.clear': 'Clear search',
    'tickets.search.result': 'Search result "{query}"',
    'tickets.search.empty.title': 'No matching ticket number in My Tickets',
    'tickets.search.empty.subtitle':
        'Try another number or return to all tickets in this draw.',
    'tickets.draw_date_label': 'Lottery draw date',
    'tickets.total_count': '{count} ticket(s) total',
    'tickets.winning_banner.title': 'Congratulations!',
    'tickets.winning_banner.message': 'You have {count} winning ticket(s).',
    'tickets.tab.current': 'Current draw',
    'tickets.tab.history': 'Past draws',
    'tickets.empty.title': 'No tickets in this draw yet',
    'tickets.empty.subtitle': 'Purchased tickets will appear here.',
    'tickets.footer_note':
        'My Tickets stores your lottery numbers and shows prize notifications here when a ticket wins.',
    'tickets.number_fallback': 'Lottery number',
    'tickets.stub.digital_label': 'Digital lottery',
    'tickets.stub.series_label': 'L6',
    'tickets.stub.price_label': '80\nTHB',
    'tickets.stub.claim_start': 'Claim',
    'tickets.stub.prize_amount': 'Reward {amount}',
    'tickets.count': '{count} ticket(s)',
    'tickets.status.winning': 'Winning ticket',
    'tickets.status.non_winning': 'Not winning',
    'tickets.status.claim_failed': 'Claim failed',
    'tickets.status.claim_cancelled': 'Claim cancelled',
    'tickets.status.approved': 'Claim approved',
    'tickets.status.paid': 'Claim paid',
    'tickets.status.pending_claim': 'Awaiting reward payout',
    'tickets.status.pending_result': 'Awaiting result',
    'tickets.prize.more': '{prize} and {count} more prizes',
    'tickets.prize.first_prize': 'First prize',
    'tickets.prize.near_first_prize': 'Adjacent first prize',
    'tickets.prize.second_prize': 'Second prize',
    'tickets.prize.third_prize': 'Third prize',
    'tickets.prize.fourth_prize': 'Fourth prize',
    'tickets.prize.fifth_prize': 'Fifth prize',
    'tickets.prize.front3': 'Front 3 digits',
    'tickets.prize.back3': 'Last 3 digits',
    'tickets.prize.back2': 'Last 2 digits',
    'tickets.prize.fallback': 'Winning prize',
    'tickets.history.title': 'Ticket history',
    'tickets.current_tooltip': 'Current draw',
    'tickets.history.header.title': 'Past draw tickets',
    'tickets.history.header.subtitle':
        'Only completed draws with a newer draw are shown here.',
    'tickets.history.list_title': 'Lottery tickets',
    'tickets.history.show_winning': 'View winning tickets',
    'tickets.history.show_all': 'View all tickets',
    'tickets.history.no_winning_summary':
        'No winning tickets this time. See you next draw.',
    'tickets.history.past_tickets_label': 'Past tickets',
    'tickets.history.completed_draw_fallback': 'Completed draw',
    'tickets.history.all_draws': 'All completed draws: {count}',
    'tickets.history.item_count': '{count} item(s)',
    'tickets.history.load_failed': 'Could not load ticket history.',
    'tickets.history.load_more_failed': 'Could not load more items.',
    'tickets.history.empty.title': 'No past tickets yet',
    'tickets.history.empty.subtitle':
        'Past tickets will appear here after a newer draw exists.',
    'tickets.history.winning_empty.title':
        'No winning tickets found in this draw',
    'tickets.history.winning_empty.subtitle':
        'Return to all tickets or check another past draw.',
    'common.loading_more': 'Loading...',
    'common.load_more': 'Load more',
    'common.all_loaded': 'All items loaded',
    'tickets.detail.title': 'Ticket details',
    'common.back': 'Back',
    'tickets.not_found': 'Ticket was not found',
    'tickets.label.lottery_number': 'Lottery number',
    'tickets.label.draw': 'Draw',
    'tickets.label.draw_date': 'Draw date',
    'tickets.label.lottery_draw_date': 'Lottery draw date',
    'tickets.label.draw_number': 'Draw number',
    'tickets.label.set_number': 'Set number',
    'tickets.label.count': 'Quantity',
    'tickets.label.prize_amount': 'Prize amount',
    'tickets.label.recipient': 'Recipient',
    'tickets.label.payout_channel': 'Payout channel',
    'tickets.label.net_amount': 'Net amount',
    'tickets.label.submitted_at': 'Submitted at',
    'tickets.label.prize': 'Prize',
    'tickets.label.government_lottery': 'Government lottery',
    'tickets.claim.view_claim': 'View claim',
    'tickets.claim.view_reward': 'View reward',
    'tickets.claim.start': 'Claim reward',
    'tickets.claim.pin_title': 'Enter PIN',
    'tickets.claim.title': 'Claim reward',
    'tickets.claim.confirm_title': 'Confirm reward claim',
    'tickets.claim.already_claimed.title': 'Claim already submitted',
    'tickets.claim.already_claimed.subtitle':
        'Track this claim from the claim detail page.',
    'tickets.claim.loading': 'Loading reward information...',
    'tickets.claim.load_failed': 'Could not load reward claim information.',
    'tickets.claim.submit_failed': 'Could not submit claim. Please try again.',
    'tickets.claim.biometric_unavailable':
        'Biometric verification is unavailable.',
    'tickets.claim.biometric_failed':
        'Biometric verification failed. Please use PIN.',
    'tickets.claim.pin_invalid': 'Incorrect PIN. Please try again.',
    'tickets.claim.pin_locked':
        'Too many incorrect PIN attempts. Please wait and try again.',
    'tickets.claim.pin_setup_required':
        'Please set up PIN before making this request.',
    'tickets.claim.pin_assertion_invalid':
        'Biometric verification expired. Please verify PIN again.',
    'tickets.claim.conflict':
        'This item was already processed. Please refresh the status.',
    'tickets.claim.payout_method_title': 'Reward payout channel',
    'tickets.claim.wallet.title': 'G Wallet',
    'tickets.claim.wallet.account_title': 'G Wallet x {suffix}',
    'tickets.claim.wallet.subtitle':
        'Receive funds in G-Wallet within 2 hours.',
    'tickets.claim.bank.title': 'Bank account',
    'tickets.claim.bank.subtitle_ready':
        'Receive funds in your saved bank account.',
    'tickets.claim.bank.subtitle_missing':
        'Add a reward payout account before choosing this channel.',
    'tickets.claim.bank.account_number': 'Account number',
    'tickets.claim.add_bank': 'Add reward payout account',
    'tickets.claim.unavailable.pending_result':
        'This ticket is still waiting for results.',
    'tickets.claim.unavailable.non_winning':
        'This ticket did not win in this draw.',
    'tickets.claim.unavailable.winning_not_open':
        'A winning result was found, but reward claims are not open yet.',
    'tickets.claim.unavailable.default': 'This item cannot be claimed yet.',
    'tickets.claim.enter_pin': 'Enter 6-digit PIN',
    'tickets.claim.processing.title': 'Reward payout is processing',
    'tickets.claim.processing.subtitle':
        'The reward will reach the recipient account within 2 hours after the request succeeds.',
    'tickets.claim.view_my_tickets': 'View My Tickets',
    'tickets.image.unavailable': 'Ticket image cannot be displayed',
    'tickets.image.preparing': 'Ticket image is being prepared',
    'tickets.image.open_preview': 'View ticket image',
    'tickets.image.close_preview': 'Close ticket image',
    'tickets.image.alt': 'Ticket image for number {number}',
    'tickets.image.government_lottery_english': 'THAI GOVERNMENT LOTTERY',
    'tickets.image.digital_watermark': 'DIGITAL',
    'tickets.image.digital_number_label': 'Digital lottery number',
    'tickets.image.current_draw': 'Current draw',
    'tickets.image.digital_type': 'Digital ticket',
    'tickets.image.sold': 'Sold',
    'tickets.image.tenant_fallback': 'App',
    'tickets.image.modal_note':
        'This digital ticket is stored in {site} for {product}.',
  },
};
