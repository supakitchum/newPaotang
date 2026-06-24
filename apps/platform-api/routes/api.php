<?php

use App\Modules\Auth\Http\Controllers\AdminAccountSecurityController;
use App\Modules\Auth\Http\Controllers\AdminAuthController;
use App\Modules\Auth\Http\Controllers\CustomerRealtimeController;
use App\Modules\Activities\Http\Controllers\CustomerActivityController;
use App\Modules\Activities\Http\Controllers\PublicActivityController;
use App\Modules\Activities\Http\Controllers\TenantActivityController;
use App\Modules\Rbac\Http\Controllers\AdminMenuController;
use App\Modules\AdminOperations\Http\Controllers\AdminOperationsController;
use App\Modules\AdminOperations\Http\Controllers\AssetController;
use App\Modules\AdminOperations\Http\Controllers\BoMenuCompletionController;
use App\Modules\AdminOperations\Http\Controllers\TenantAnnouncementController;
use App\Modules\AdminOperations\Http\Controllers\TenantPaymentSettingsController;
use App\Modules\AdminOperations\Http\Controllers\TenantSeoController;
use App\Modules\Rbac\Http\Controllers\AdminRoleController;
use App\Modules\Rbac\Http\Controllers\AdminUserController;
use App\Modules\CentralStock\Http\Controllers\CentralAllocationController;
use App\Modules\CentralStock\Http\Controllers\CentralGameController;
use App\Modules\CentralStock\Http\Controllers\LotteryImageOperationsController;
use App\Modules\CentralStock\Http\Controllers\QueueProcessController;
use App\Modules\Reward\Http\Controllers\CentralRewardController;
use App\Modules\Reward\Http\Controllers\CentralRewardEntryController;
use App\Modules\Growth\Http\Controllers\CentralSettlementController;
use App\Modules\CentralStock\Http\Controllers\CentralStockController;
use App\Modules\Auth\Http\Controllers\CustomerAuthController;
use App\Modules\Auth\Http\Controllers\CustomerLineAuthController;
use App\Modules\Auth\Http\Controllers\CustomerPasswordResetController;
use App\Modules\Commerce\Http\Controllers\CustomerCommerceController;
use App\Modules\Growth\Http\Controllers\CustomerAffiliateController;
use App\Modules\PartnerStore\Http\Controllers\CustomerReservationController;
use App\Modules\PartnerStore\Http\Controllers\PublicAssetController;
use App\Modules\Reward\Http\Controllers\CustomerRewardController;
use App\Modules\Reward\Http\Controllers\InternalRewardIngestController;
use App\Modules\Health\Http\Controllers\HealthController;
use App\Modules\Partner\Http\Controllers\PartnerApiClientController;
use App\Modules\CentralStock\Http\Controllers\PartnerLotteryBrandingAssetController;
use App\Modules\Partner\Http\Controllers\PartnerProvisioningController;
use App\Modules\Partner\Http\Controllers\PartnerSyncController;
use App\Modules\CentralStock\Http\Controllers\PartnerQuotaController;
use App\Modules\PublicSite\Http\Controllers\PublicGameController;
use App\Modules\PublicSite\Http\Controllers\PublicContentController;
use App\Modules\PublicSite\Http\Controllers\PublicVisitController;
use App\Modules\Reward\Http\Controllers\PublicRewardController;
use App\Modules\PublicSite\Http\Controllers\PublicSiteConfigController;
use App\Modules\PartnerStore\Http\Controllers\PublicStockImageController;
use App\Modules\PartnerStore\Http\Controllers\PublicStockSearchController;
use App\Modules\Pricing\Http\Controllers\AdminSalePriceRuleController;
use App\Modules\Growth\Http\Controllers\ReportController;
use App\Modules\Tenancy\Http\Controllers\TenantConfigurationController;
use App\Modules\Commerce\Http\Controllers\TenantCommerceController;
use App\Modules\Growth\Http\Controllers\TenantGrowthController;
use App\Modules\Maintenance\Http\Controllers\CentralMaintenanceController;
use App\Modules\Maintenance\Http\Controllers\TenantMaintenanceController;
use App\Modules\LineNotifications\Http\Controllers\CustomerLineNotificationController;
use App\Modules\LineNotifications\Http\Controllers\TenantLineNotificationController;
use App\Modules\SmsOtp\Http\Controllers\CustomerSmsOtpController;
use App\Modules\SmsOtp\Http\Controllers\TenantSmsOtpController;
use App\Modules\TelegramNotifications\Http\Controllers\CentralTelegramNotificationController;
use App\Modules\Translations\Http\Controllers\CentralTranslationController;
use App\Modules\Translations\Http\Controllers\PublicTranslationController;
use App\Modules\StorageConnections\Http\Controllers\CentralStorageConnectionController;
use App\Modules\Reward\Http\Controllers\TenantRewardClaimController;
use App\Modules\Reward\Http\Controllers\TenantRewardWinnersController;
use App\Modules\PartnerStore\Http\Controllers\TenantReservationController;
use App\Modules\PartnerStore\Http\Controllers\TenantStockController;
use App\Modules\SupportAccess\Http\Controllers\TenantSupportAccessController;
use App\Modules\Webhook\Http\Controllers\WebhookController;
use Illuminate\Support\Facades\Route;

Route::get('/health', [HealthController::class, 'summary']);
Route::get('/health/live', [HealthController::class, 'live']);
Route::get('/health/ready', [HealthController::class, 'ready']);
Route::post('/internal/reward-ingest/sanook', [InternalRewardIngestController::class, 'sanook']);
Route::post('/internal/reward-ingest/thairath', [InternalRewardIngestController::class, 'thairath']);

Route::get('/public/admin-site-config', [PublicSiteConfigController::class, 'admin']);
Route::get('/public/site-config', [PublicSiteConfigController::class, 'show']);
Route::get('/public/translations', [PublicTranslationController::class, 'bundle']);
Route::get('/public/seo/page', [PublicContentController::class, 'seoPage']);
Route::get('/public/news', [PublicContentController::class, 'news']);
Route::get('/public/news/modal', [PublicContentController::class, 'newsModal']);
Route::get('/public/news/{slug}', [PublicContentController::class, 'newsDetail']);
Route::get('/public/activities', [PublicActivityController::class, 'index']);
Route::get('/public/activities/{slug}', [PublicActivityController::class, 'show']);
Route::get('/public/stores', [PublicContentController::class, 'stores']);
Route::post('/public/monitor/visit', [PublicVisitController::class, 'track']);
Route::get('/public/games/current', [PublicGameController::class, 'current']);
Route::get('/public/stock/search', [PublicStockSearchController::class, 'index']);
Route::get('/public/stock/images/{token}.webp', [PublicStockImageController::class, 'show']);
Route::get('/public/assets/{path}', [PublicAssetController::class, 'show'])->where('path', '.*');
Route::post('/public/affiliate/referrals/click', [CustomerAffiliateController::class, 'trackReferralVisit']);
Route::get('/public/results/latest', [PublicRewardController::class, 'latest']);
Route::get('/public/results/live/latest', [PublicRewardController::class, 'liveLatest']);
Route::get('/public/results/live/{game_id}', [PublicRewardController::class, 'liveShow']);
Route::get('/public/results/{game_id}', [PublicRewardController::class, 'show']);

Route::post('/customer/auth/register', [CustomerAuthController::class, 'register']);
Route::post('/customer/auth/login', [CustomerAuthController::class, 'login']);
Route::post('/customer/auth/otp/request', [CustomerSmsOtpController::class, 'request']);
Route::post('/customer/auth/otp/verify', [CustomerSmsOtpController::class, 'verify']);
Route::post('/customer/auth/password/forgot', [CustomerPasswordResetController::class, 'forgot']);
Route::post('/customer/auth/password/reset', [CustomerPasswordResetController::class, 'reset']);
Route::post('/customer/auth/password/reset/otp', [CustomerSmsOtpController::class, 'resetPassword']);
Route::post('/customer/auth/line/login', [CustomerLineAuthController::class, 'login']);
Route::get('/customer/auth/line/callback', [CustomerLineAuthController::class, 'callback']);
Route::post('/customer/auth/line/link-phone', [CustomerLineAuthController::class, 'linkPhone']);
Route::post('/customer/auth/refresh', [CustomerAuthController::class, 'refresh']);
Route::post('/customer/auth/logout', [CustomerAuthController::class, 'logout'])->middleware('customer.auth');
Route::get('/customer/auth/me', [CustomerAuthController::class, 'me'])->middleware('customer.auth');
Route::get('/customer/auth/pin/status', [CustomerAuthController::class, 'pinStatus'])->middleware('customer.auth');
Route::post('/customer/auth/pin/setup', [CustomerAuthController::class, 'setupPin'])->middleware('customer.auth');
Route::post('/customer/auth/pin/verify', [CustomerAuthController::class, 'verifyPin'])->middleware('customer.auth');
Route::post('/customer/auth/pin/change', [CustomerAuthController::class, 'changePin'])->middleware('customer.auth');
Route::post('/customer/auth/pin/reset/verify-password', [CustomerAuthController::class, 'verifyPinResetPassword'])->middleware('customer.auth');
Route::post('/customer/auth/pin/reset', [CustomerAuthController::class, 'resetPin'])->middleware('customer.auth');
Route::post('/customer/auth/pin/reset/request-otp', [CustomerSmsOtpController::class, 'requestPinReset'])->middleware('customer.auth');
Route::post('/customer/auth/pin/reset/verify-otp', [CustomerSmsOtpController::class, 'verifyPinReset'])->middleware('customer.auth');
Route::post('/customer/auth/pin/reset/confirm-otp', [CustomerSmsOtpController::class, 'confirmPinReset'])->middleware('customer.auth');
Route::get('/customer/profile', [CustomerAuthController::class, 'profile'])->middleware('customer.auth');
Route::patch('/customer/profile', [CustomerAuthController::class, 'updateProfile'])->middleware('customer.auth');
Route::get('/customer/line-notifications', [CustomerLineNotificationController::class, 'show'])->middleware('customer.auth');
Route::patch('/customer/line-notifications', [CustomerLineNotificationController::class, 'update'])->middleware('customer.auth');
Route::delete('/customer/line-notifications', [CustomerLineNotificationController::class, 'disconnect'])->middleware('customer.auth');
Route::post('/customer/realtime/auth', [CustomerRealtimeController::class, 'authorize'])->middleware('customer.auth');
Route::get('/customer/cart', [CustomerCommerceController::class, 'cart'])->middleware('customer.auth');
Route::post('/customer/checkout', [CustomerCommerceController::class, 'checkout'])->middleware('customer.auth');
Route::get('/customer/wallet', [CustomerCommerceController::class, 'wallet'])->middleware('customer.auth');
Route::get('/customer/wallet/ledger', [CustomerCommerceController::class, 'walletLedger'])->middleware('customer.auth');
Route::get('/customer/orders', [CustomerCommerceController::class, 'orders'])->middleware('customer.auth');
Route::get('/customer/orders/{order_id}', [CustomerCommerceController::class, 'order'])->middleware('customer.auth');
Route::get('/customer/tickets', [CustomerCommerceController::class, 'tickets'])->middleware('customer.auth');
Route::get('/customer/tickets/history', [CustomerCommerceController::class, 'ticketHistory'])->middleware('customer.auth');
Route::get('/customer/tickets/{ticket_id}/reward-status', [CustomerRewardController::class, 'ticketRewardStatus'])->middleware('customer.auth');
Route::get('/customer/tickets/{ticket_id}', [CustomerCommerceController::class, 'ticket'])->middleware('customer.auth');
Route::get('/customer/reward-claims', [CustomerRewardController::class, 'claims'])->middleware('customer.auth');
Route::post('/customer/reward-claims', [CustomerRewardController::class, 'createClaim'])->middleware('customer.auth');
Route::get('/customer/reward-claims/{claim_id}', [CustomerRewardController::class, 'claim'])->middleware('customer.auth');
Route::get('/customer/activities', [CustomerActivityController::class, 'index'])->middleware('customer.auth');
Route::get('/customer/activities/{activity_id}', [CustomerActivityController::class, 'show'])->middleware('customer.auth');
Route::get('/customer/activities/{activity_id}/rights', [CustomerActivityController::class, 'rights'])->middleware('customer.auth');
Route::post('/customer/activities/{activity_id}/entries', [CustomerActivityController::class, 'storeEntry'])->middleware('customer.auth');
Route::get('/customer/activity-awards', [CustomerActivityController::class, 'awards'])->middleware('customer.auth');
Route::get('/customer/activity-claims', [CustomerActivityController::class, 'claims'])->middleware('customer.auth');
Route::post('/customer/activity-claims', [CustomerActivityController::class, 'createClaim'])->middleware('customer.auth');
Route::get('/customer/activity-claims/{claim_id}', [CustomerActivityController::class, 'claim'])->middleware('customer.auth');
Route::get('/customer/topups', [CustomerCommerceController::class, 'topups'])->middleware('customer.auth');
Route::post('/customer/topups', [CustomerCommerceController::class, 'createTopup'])->middleware('customer.auth');
Route::post('/customer/topups/credit', [CustomerCommerceController::class, 'createCreditTopup'])->middleware('customer.auth');
Route::post('/customer/topups/{topup_id}/slip', [CustomerCommerceController::class, 'uploadTopupSlip'])->middleware('customer.auth');
Route::get('/customer/topups/{topup_id}', [CustomerCommerceController::class, 'topup'])->middleware('customer.auth');
Route::delete('/customer/topups/{topup_id}', [CustomerCommerceController::class, 'cancelTopup'])->middleware('customer.auth');
Route::get('/customer/affiliate', [CustomerAffiliateController::class, 'overview'])->middleware('customer.auth');
Route::post('/customer/affiliate', [CustomerAffiliateController::class, 'register'])->middleware('customer.auth');
Route::post('/customer/affiliate/referrals/apply', [CustomerAffiliateController::class, 'applyReferral'])->middleware('customer.auth');
Route::get('/customer/affiliate/commissions', [CustomerAffiliateController::class, 'commissions'])->middleware('customer.auth');
Route::get('/customer/affiliate/payouts', [CustomerAffiliateController::class, 'payouts'])->middleware('customer.auth');
Route::post('/customer/affiliate/payouts', [CustomerAffiliateController::class, 'createPayout'])->middleware('customer.auth');
Route::post('/customer/reservations', [CustomerReservationController::class, 'store'])
    ->middleware('customer.auth');
Route::post('/customer/reservations/{reservation_id}/release', [CustomerReservationController::class, 'release'])
    ->middleware('customer.auth');

Route::post('/auth/admin/login', [AdminAuthController::class, 'login']);
Route::post('/auth/admin/refresh', [AdminAuthController::class, 'refresh']);
Route::post('/auth/admin/logout', [AdminAuthController::class, 'logout'])->middleware('admin.auth');
Route::get('/auth/admin/me', [AdminAuthController::class, 'me'])->middleware('admin.auth');
Route::patch('/auth/admin/me', [AdminAuthController::class, 'updateMe'])->middleware('admin.auth');
Route::post('/auth/admin/password/forgot', [AdminAccountSecurityController::class, 'forgotPassword']);
Route::post('/auth/admin/password/reset', [AdminAccountSecurityController::class, 'resetPassword']);
Route::post('/auth/admin/password/change', [AdminAccountSecurityController::class, 'changePassword'])
    ->middleware(['admin.auth', 'support.block:change_password']);
Route::get('/auth/admin/2fa', [AdminAccountSecurityController::class, 'twoFactorStatus'])
    ->middleware('admin.auth');
Route::delete('/auth/admin/2fa', [AdminAccountSecurityController::class, 'disableTwoFactor'])
    ->middleware(['admin.auth', 'support.block:change_2fa']);
Route::post('/auth/admin/2fa/setup', [AdminAccountSecurityController::class, 'setupTwoFactor'])
    ->middleware(['admin.auth', 'support.block:change_2fa']);
Route::post('/auth/admin/2fa/enable', [AdminAccountSecurityController::class, 'enableTwoFactor'])
    ->middleware(['admin.auth', 'support.block:change_2fa']);
Route::post('/auth/admin/2fa/recovery-codes', [AdminAccountSecurityController::class, 'rotateRecoveryCodes'])
    ->middleware(['admin.auth', 'support.block:change_2fa']);
Route::post('/auth/admin/2fa/verify', [AdminAccountSecurityController::class, 'verifyTwoFactor']);

Route::get('/admin/translations/runtime', [CentralTranslationController::class, 'runtime'])
    ->middleware('admin.auth');

Route::get('/admin/central/menu', [AdminMenuController::class, 'central'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/dashboard/summary', [AdminOperationsController::class, 'centralDashboardSummary'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/dashboard/{section}/summary', [AdminOperationsController::class, 'centralDashboardSection'])
    ->whereIn('section', ['sales', 'partner', 'wallet', 'payout', 'monitor'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/realtime/auth', [AdminOperationsController::class, 'centralRealtimeAuth'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/queue-processes', [QueueProcessController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/queue-processes/{type}/{id}', [QueueProcessController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/queue-processes/{type}/{id}/retry', [QueueProcessController::class, 'retry'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/queue-processes/{type}/{id}/cancel', [QueueProcessController::class, 'cancel'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/menu-management', [AdminOperationsController::class, 'centralMenuManagement'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/menu-management', [AdminOperationsController::class, 'centralUpdateMenuManagement'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/audit-logs', [AdminOperationsController::class, 'centralAuditLogs'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/audit-logs/{audit_log_id}', [AdminOperationsController::class, 'centralAuditLog'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-monitoring', [BoMenuCompletionController::class, 'partnerMonitoringIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-monitoring/{monitoring_profile_id}', [BoMenuCompletionController::class, 'partnerMonitoringShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partner-monitoring/{monitoring_profile_id}', [BoMenuCompletionController::class, 'partnerMonitoringUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-usage', [BoMenuCompletionController::class, 'partnerUsageIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-usage/{usage_meter_id}', [BoMenuCompletionController::class, 'partnerUsageShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partner-usage/{usage_meter_id}', [BoMenuCompletionController::class, 'partnerUsageUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/billing-plans', [BoMenuCompletionController::class, 'billingPlansIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/billing-plans', [BoMenuCompletionController::class, 'billingPlansStore'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/billing-plans/{billing_plan_id}', [BoMenuCompletionController::class, 'billingPlansShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/billing-plans/{billing_plan_id}', [BoMenuCompletionController::class, 'billingPlansUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/billing-bindings', [BoMenuCompletionController::class, 'billingBindingsIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/billing-bindings/{billing_binding_id}', [BoMenuCompletionController::class, 'billingBindingsShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/billing-bindings/{billing_binding_id}', [BoMenuCompletionController::class, 'billingBindingsUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/alert-policies', [BoMenuCompletionController::class, 'alertPoliciesIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/alert-policies', [BoMenuCompletionController::class, 'alertPoliciesStore'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/alert-policies/{alert_policy_id}', [BoMenuCompletionController::class, 'alertPoliciesShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/alert-policies/{alert_policy_id}', [BoMenuCompletionController::class, 'alertPoliciesUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/alert-events', [BoMenuCompletionController::class, 'alertEventsIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/alert-events/{alert_event_id}', [BoMenuCompletionController::class, 'alertEventsShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/alert-events/{alert_event_id}/acknowledge', [BoMenuCompletionController::class, 'alertEventsAcknowledge'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/alert-events/{alert_event_id}/resolve', [BoMenuCompletionController::class, 'alertEventsResolve'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/system-settings', [BoMenuCompletionController::class, 'systemSettingsShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/system-settings', [BoMenuCompletionController::class, 'systemSettingsUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/webhook-logs', [BoMenuCompletionController::class, 'webhookLogsIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/webhook-logs/{webhook_log_id}', [BoMenuCompletionController::class, 'webhookLogsShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/sync-logs', [BoMenuCompletionController::class, 'centralSyncLogs'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/sale-price-games', [AdminSalePriceRuleController::class, 'gameOptions'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/sale-price-rules', [AdminSalePriceRuleController::class, 'centralIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/sale-price-rules', [AdminSalePriceRuleController::class, 'centralStore'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/sale-price-rules/{sale_price_rule_id}', [AdminSalePriceRuleController::class, 'centralShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/sale-price-rules/{sale_price_rule_id}', [AdminSalePriceRuleController::class, 'centralUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-payout-rule-games', [BoMenuCompletionController::class, 'centralRewardPayoutRuleGames'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-payout-rules', [BoMenuCompletionController::class, 'centralRewardPayoutRulesIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-payout-rules/{payout_rule_id}', [BoMenuCompletionController::class, 'centralRewardPayoutRulesShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/reward-payout-rules/{payout_rule_id}', [BoMenuCompletionController::class, 'centralRewardPayoutRulesUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/assets/uploads', [AssetController::class, 'centralUpload'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/assets/{asset_id}', [AssetController::class, 'centralShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/assets/{asset_id}/commit', [AssetController::class, 'centralCommit'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/assets/{asset_id}/local-upload', [AssetController::class, 'centralLocalUpload'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/maintenance', [CentralMaintenanceController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-maintenance/{partner_id}', [CentralMaintenanceController::class, 'partnerShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/partner-maintenance/{partner_id}', [CentralMaintenanceController::class, 'partnerUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/maintenance/{tenant_id}', [CentralMaintenanceController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/maintenance/{tenant_id}', [CentralMaintenanceController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/telegram-notifications/bot', [CentralTelegramNotificationController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/telegram-notifications/bot', [CentralTelegramNotificationController::class, 'updateBot'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::delete('/admin/central/telegram-notifications/bot', [CentralTelegramNotificationController::class, 'disconnectBot'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/telegram-notifications/chats/sync', [CentralTelegramNotificationController::class, 'syncChats'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/telegram-notifications/chats', [CentralTelegramNotificationController::class, 'chats'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/telegram-notifications/test-send', [CentralTelegramNotificationController::class, 'testSend'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/telegram-notifications/routes', [CentralTelegramNotificationController::class, 'routes'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/telegram-notifications/routes', [CentralTelegramNotificationController::class, 'updateRoutes'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/telegram-notifications/templates', [CentralTelegramNotificationController::class, 'templates'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/telegram-notifications/templates/{event_key}', [CentralTelegramNotificationController::class, 'updateTemplate'])
    ->where('event_key', '.*')
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/telegram-notifications/deliveries', [CentralTelegramNotificationController::class, 'deliveries'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/storage-connections/aws-s3', [CentralStorageConnectionController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/storage-connections/aws-s3', [CentralStorageConnectionController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/storage-connections/upload-routes', [CentralStorageConnectionController::class, 'updateRoutes'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::delete('/admin/central/storage-connections/aws-s3', [CentralStorageConnectionController::class, 'disconnect'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/storage-connections/aws-s3/test', [CentralStorageConnectionController::class, 'test'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/translations/runtime', [CentralTranslationController::class, 'runtime'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/translations/languages', [CentralTranslationController::class, 'languages'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::match(['post', 'patch'], '/admin/central/translations/languages', [CentralTranslationController::class, 'upsertLanguage'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/translations/keys', [CentralTranslationController::class, 'keys'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/translations/drafts/{key_id}', [CentralTranslationController::class, 'saveDraft'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/translations/deploy-requests', [CentralTranslationController::class, 'deployRequests'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests', [CentralTranslationController::class, 'createDeployRequest'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests/{id}/submit', [CentralTranslationController::class, 'submitDeployRequest'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests/{id}/cancel', [CentralTranslationController::class, 'cancelDeployRequest'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests/{id}/preview-session', [CentralTranslationController::class, 'previewSession'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests/{id}/approve', [CentralTranslationController::class, 'approve'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/translations/deploy-requests/{id}/reject', [CentralTranslationController::class, 'reject'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partners', [PartnerProvisioningController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partners', [PartnerProvisioningController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partners/{partner_id}', [PartnerProvisioningController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partners/{partner_id}', [PartnerProvisioningController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partners/{partner_id}/profile', [PartnerProvisioningController::class, 'updateProfile'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partners/{partner_id}/lottery-branding-assets', [PartnerLotteryBrandingAssetController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/partners/{partner_id}/lottery-branding-assets', [PartnerLotteryBrandingAssetController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partners/{partner_id}/lottery-branding/preview', [PartnerLotteryBrandingAssetController::class, 'preview'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partners/{partner_id}/provision', [PartnerProvisioningController::class, 'provision'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partners/{partner_id}/suspend', [PartnerProvisioningController::class, 'suspend'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partners/{partner_id}/unsuspend', [PartnerProvisioningController::class, 'unsuspend'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-api-clients', [PartnerApiClientController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partner-api-clients', [PartnerApiClientController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partner-api-clients/{client_id}', [PartnerApiClientController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::delete('/admin/central/partner-api-clients/{client_id}', [PartnerApiClientController::class, 'destroy'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/games', [CentralGameController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/games', [CentralGameController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/games/{game_id}', [CentralGameController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/games/{game_id}', [CentralGameController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/games/{game_id}/close', [CentralGameController::class, 'close'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/games/{game_id}/trigger-reward-scraper', [CentralGameController::class, 'triggerRewardScraper'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/games/{game_id}/archive', [CentralGameController::class, 'archive'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock', [CentralStockController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/summary', [CentralStockController::class, 'summary'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/patterns', [CentralStockController::class, 'patterns'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/limit-overrides', [CentralStockController::class, 'limitOverrides'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/settings', [CentralStockController::class, 'settings'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/stock/settings', [CentralStockController::class, 'updateSettings'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/stock/limit-settings', [CentralStockController::class, 'updateLimitSettings'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/stock/limit-overrides', [CentralStockController::class, 'updateLimitOverrides'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/{game_id}/numbers/{full_number}', [CentralStockController::class, 'numberDetail'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/generation-batches', [CentralStockController::class, 'generationBatches'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/stock/generation-batches/{batch_id}', [CentralStockController::class, 'generationBatch'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/stock/generate', [CentralStockController::class, 'generate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/stock/imports', [CentralStockController::class, 'imports'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/stock/exports', [CentralStockController::class, 'exports'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/stock/{stock_item_id}/recall', [CentralStockController::class, 'recall'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/readiness', [LotteryImageOperationsController::class, 'readiness'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/games', [LotteryImageOperationsController::class, 'games'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/background-asset-sets', [LotteryImageOperationsController::class, 'backgroundSets'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/lottery-images/background-asset-sets/import-zip', [LotteryImageOperationsController::class, 'importBackgroundZip'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/background-asset-sets/import-jobs/{import_job_id}', [LotteryImageOperationsController::class, 'backgroundZipImportStatus'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/lottery-images/background-asset-sets', [LotteryImageOperationsController::class, 'upsertBackgroundSet'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/lottery-images/background-asset-sets/{asset_set_id}', [LotteryImageOperationsController::class, 'updateBackgroundSetStatus'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/lottery-images/preview', [LotteryImageOperationsController::class, 'preview'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/layout', [LotteryImageOperationsController::class, 'layout'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/lottery-images/layout', [LotteryImageOperationsController::class, 'updateLayout'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/mix', [LotteryImageOperationsController::class, 'mix'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/lottery-images/mix', [LotteryImageOperationsController::class, 'updateMix'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/lottery-images/retry-pending', [LotteryImageOperationsController::class, 'retryPending'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/lottery-images/production-readiness', [LotteryImageOperationsController::class, 'productionReadiness'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/partner-quotas', [PartnerQuotaController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/partner-quotas', [PartnerQuotaController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/partner-quotas/{quota_id}', [PartnerQuotaController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/allocations', [CentralAllocationController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/allocation-options/partners', [CentralAllocationController::class, 'partnerOptions'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/allocation-options/tenants', [CentralAllocationController::class, 'tenantOptions'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/allocation-options/games', [CentralAllocationController::class, 'gameOptions'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/allocations', [CentralAllocationController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/allocations/open-all-partners', [CentralAllocationController::class, 'openAllPartners'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/allocations/partner-percent', [CentralAllocationController::class, 'updatePartnerPercent'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/allocations/{allocation_id}', [CentralAllocationController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/allocations/{allocation_id}/recall-all', [CentralAllocationController::class, 'recallAll'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/allocations/{allocation_id}/redistribute', [CentralAllocationController::class, 'redistribute'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/allocations/{allocation_id}/cancel', [CentralAllocationController::class, 'cancel'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/winners/games', [CentralRewardController::class, 'winnerGames'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/winners', [CentralRewardController::class, 'winners'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-entry/sessions/current', [CentralRewardEntryController::class, 'current'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-entry/owner-queue', [CentralRewardEntryController::class, 'ownerQueue'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-entry/sessions/{session_id}', [CentralRewardEntryController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::put('/admin/central/reward-entry/sessions/{session_id}/submission', [CentralRewardEntryController::class, 'saveSubmission'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/reward-entry/sessions/{session_id}/submit', [CentralRewardEntryController::class, 'submit'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reward-entry/sessions/{session_id}/comparison', [CentralRewardEntryController::class, 'comparison'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/reward-entry/sessions/{session_id}/trigger-scraper', [CentralRewardEntryController::class, 'triggerScraper'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/reward-entry/sessions/{session_id}/resolve', [CentralRewardEntryController::class, 'resolve'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/rewards', [CentralRewardController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards', [CentralRewardController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/rewards/live-settings', [CentralRewardController::class, 'liveSettings'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/rewards/live-settings', [CentralRewardController::class, 'updateLiveSettings'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/rewards/{reward_result_id}', [CentralRewardController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/rewards/{reward_result_id}', [CentralRewardController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/rewards/{reward_result_id}/check-batches', [CentralRewardController::class, 'checkBatches'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards/{reward_result_id}/verify', [CentralRewardController::class, 'verify'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards/{reward_result_id}/publish', [CentralRewardController::class, 'publish'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards/{reward_result_id}/confirm-live', [CentralRewardController::class, 'confirmLive'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards/{reward_result_id}/redraw', [CentralRewardController::class, 'redraw'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/rewards/{reward_result_id}/correct', [CentralRewardController::class, 'correct'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/reports/{report_key}', [ReportController::class, 'centralReport'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/reports/{report_key}/exports', [ReportController::class, 'createCentralExport'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/export-jobs/{export_job_id}', [ReportController::class, 'centralExportJob'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/export-jobs/{export_job_id}/download', [ReportController::class, 'centralDownload'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/settlements', [CentralSettlementController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/settlements/{settlement_id}', [CentralSettlementController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/settlements/{settlement_id}/approve', [CentralSettlementController::class, 'approve'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/admin-users', [AdminUserController::class, 'centralIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/admin-users', [AdminUserController::class, 'centralStore'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/admin-users/{admin_user_id}', [AdminUserController::class, 'centralShow'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/admin-users/{admin_user_id}', [AdminUserController::class, 'centralUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::delete('/admin/central/admin-users/{admin_user_id}', [AdminUserController::class, 'centralDestroy'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::get('/admin/central/roles', [AdminRoleController::class, 'centralIndex'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::post('/admin/central/roles', [AdminRoleController::class, 'centralStore'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::patch('/admin/central/roles/{role_id}', [AdminRoleController::class, 'centralUpdate'])
    ->middleware(['admin.auth', 'admin.scope:central']);
Route::delete('/admin/central/roles/{role_id}', [AdminRoleController::class, 'centralDestroy'])
    ->middleware(['admin.auth', 'admin.scope:central']);

Route::get('/admin/tenant/menu', [AdminMenuController::class, 'tenant'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/realtime/auth', [AdminOperationsController::class, 'tenantRealtimeAuth'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/dashboard/summary', [AdminOperationsController::class, 'tenantDashboardSummary'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/menu-management', [AdminOperationsController::class, 'tenantMenuManagement'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/menu-management', [AdminOperationsController::class, 'tenantUpdateMenuManagement'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/audit-logs', [AdminOperationsController::class, 'tenantAuditLogs'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/audit-logs/{audit_log_id}', [AdminOperationsController::class, 'tenantAuditLog'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/maintenance', [TenantMaintenanceController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/maintenance', [TenantMaintenanceController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/maintenance/events', [TenantMaintenanceController::class, 'events'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/maintenance/bypasses', [TenantMaintenanceController::class, 'bypasses'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/maintenance/bypasses', [TenantMaintenanceController::class, 'createBypass'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/maintenance/bypasses/{bypass_id}', [TenantMaintenanceController::class, 'revokeBypass'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/support-access', [TenantSupportAccessController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access', [TenantSupportAccessController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/support-access/{support_access_id}', [TenantSupportAccessController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access/{support_access_id}/approve', [TenantSupportAccessController::class, 'approve'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access/{support_access_id}/revoke', [TenantSupportAccessController::class, 'revoke'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access/{support_access_id}/impersonate', [TenantSupportAccessController::class, 'impersonate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access/{support_access_id}/elevated-actions', [TenantSupportAccessController::class, 'elevatedAction'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/support-access/{support_access_id}/end-session', [TenantSupportAccessController::class, 'endSession'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/settings', [TenantConfigurationController::class, 'settings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/settings', [TenantConfigurationController::class, 'updateSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/theme', [TenantConfigurationController::class, 'theme'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/theme', [TenantConfigurationController::class, 'updateTheme'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/assets/uploads', [AssetController::class, 'tenantUpload'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/assets/{asset_id}', [AssetController::class, 'tenantShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/assets/{asset_id}/commit', [AssetController::class, 'tenantCommit'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/assets/{asset_id}/local-upload', [AssetController::class, 'tenantLocalUpload'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/payment-settings', [TenantPaymentSettingsController::class, 'settings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/payment-settings', [TenantPaymentSettingsController::class, 'updateSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/payment-settings/deepay-kbank', [TenantPaymentSettingsController::class, 'deepayKbankConnection'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/payment-settings/deepay-kbank', [TenantPaymentSettingsController::class, 'saveDeepayKbankConnection'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/payment-settings/deepay-kbank', [TenantPaymentSettingsController::class, 'deactivateDeepayKbankConnection'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/payment-channels', [TenantPaymentSettingsController::class, 'channels'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/payment-channels', [TenantPaymentSettingsController::class, 'createChannel'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/payment-channels/{payment_channel_id}', [TenantPaymentSettingsController::class, 'showChannel'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/payment-channels/{payment_channel_id}', [TenantPaymentSettingsController::class, 'updateChannel'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/payment-channels/{payment_channel_id}', [TenantPaymentSettingsController::class, 'destroyChannel'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/seo', [TenantSeoController::class, 'settings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/seo', [TenantSeoController::class, 'updateSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/seo/pages', [TenantSeoController::class, 'pages'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/seo/pages', [TenantSeoController::class, 'createPage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/seo/pages/{page_id}', [TenantSeoController::class, 'updatePage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/seo/pages/{page_id}', [TenantSeoController::class, 'deletePage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/redirects', [TenantSeoController::class, 'redirects'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/redirects', [TenantSeoController::class, 'createRedirect'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/redirects/{redirect_id}', [TenantSeoController::class, 'updateRedirect'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/redirects/{redirect_id}', [TenantSeoController::class, 'deleteRedirect'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/announcements', [TenantAnnouncementController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/announcements', [TenantAnnouncementController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/announcements/{announcement_id}', [TenantAnnouncementController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/announcements/{announcement_id}', [TenantAnnouncementController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/announcements/{announcement_id}', [TenantAnnouncementController::class, 'destroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/announcements/{announcement_id}/image', [TenantAnnouncementController::class, 'uploadImage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/line-notifications', [TenantLineNotificationController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/line-notifications/connection', [TenantLineNotificationController::class, 'updateConnection'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/line-notifications/connection', [TenantLineNotificationController::class, 'disconnectConnection'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/line-notifications/templates', [TenantLineNotificationController::class, 'templates'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/line-notifications/templates/{event_key}', [TenantLineNotificationController::class, 'updateTemplate'])
    ->where('event_key', '.*')
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/line-notifications/templates/{event_key}/preview', [TenantLineNotificationController::class, 'previewTemplate'])
    ->where('event_key', '.*')
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/line-notifications/customers', [TenantLineNotificationController::class, 'linkedCustomers'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/line-notifications/deliveries', [TenantLineNotificationController::class, 'deliveries'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/line-notifications/test-send', [TenantLineNotificationController::class, 'testSend'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/sms-otp', [TenantSmsOtpController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/sms-otp/connection', [TenantSmsOtpController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/sms-otp/test-send', [TenantSmsOtpController::class, 'testSend'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/sms-otp/providers/{provider_id}/status', [TenantSmsOtpController::class, 'updateProviderStatus'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/password-reset-requests', [CustomerPasswordResetController::class, 'tenantIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/password-reset-requests/{request_id}/issue-link', [CustomerPasswordResetController::class, 'tenantIssueLink'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/activities', [TenantActivityController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/activities', [TenantActivityController::class, 'store'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/activity-claims', [TenantActivityController::class, 'claims'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/activity-claims/{claim_id}', [TenantActivityController::class, 'claim'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/activity-claims/{claim_id}/approve', [TenantActivityController::class, 'approveClaim'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:payout_approve']);
Route::post('/admin/tenant/activity-claims/{claim_id}/reject', [TenantActivityController::class, 'rejectClaim'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/activity-claims/{claim_id}/pay', [TenantActivityController::class, 'payClaim'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:payout_approve']);
Route::get('/admin/tenant/activities/{activity_id}', [TenantActivityController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/activities/{activity_id}', [TenantActivityController::class, 'update'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/activities/{activity_id}', [TenantActivityController::class, 'destroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/activities/{activity_id}/image', [TenantActivityController::class, 'uploadImage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/activities/{activity_id}/entries', [TenantActivityController::class, 'entries'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/activities/{activity_id}/awards', [TenantActivityController::class, 'awards'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/stock', [TenantStockController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/stock/games', [TenantStockController::class, 'games'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/stock/coverage', [TenantStockController::class, 'coverage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/stock/limit-overrides', [TenantStockController::class, 'limitOverrides'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/stock/limit-settings', [TenantStockController::class, 'updateLimitSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::put('/admin/tenant/stock/limit-overrides', [TenantStockController::class, 'updateLimitOverrides'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/stock/exports', [TenantStockController::class, 'exports'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/stock/{stock_item_id}', [TenantStockController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/reservations', [TenantReservationController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/reservations/{reservation_id}', [TenantReservationController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/reservations/{reservation_id}/cancel', [TenantReservationController::class, 'cancel'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/price-rules', [BoMenuCompletionController::class, 'priceRulesIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/price-rule-games', [BoMenuCompletionController::class, 'priceRuleGames'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/price-rules/live-settings', [BoMenuCompletionController::class, 'priceRulesLiveSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/price-rules/live-settings', [BoMenuCompletionController::class, 'priceRulesUpdateLiveSettings'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/price-rules', [BoMenuCompletionController::class, 'priceRulesStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/price-rules/{price_rule_id}', [BoMenuCompletionController::class, 'priceRulesShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/price-rules/{price_rule_id}', [BoMenuCompletionController::class, 'priceRulesUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/price-rules/{price_rule_id}', [BoMenuCompletionController::class, 'priceRulesDestroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/sale-price-games', [AdminSalePriceRuleController::class, 'gameOptions'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/sale-price-rules', [AdminSalePriceRuleController::class, 'tenantIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/sale-price-rules', [AdminSalePriceRuleController::class, 'tenantStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/sale-price-rules/{sale_price_rule_id}', [AdminSalePriceRuleController::class, 'tenantShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/sale-price-rules/{sale_price_rule_id}', [AdminSalePriceRuleController::class, 'tenantUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/domains', [BoMenuCompletionController::class, 'domainsIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/domains', [BoMenuCompletionController::class, 'domainsStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/domains/{domain_id}', [BoMenuCompletionController::class, 'domainsShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/domains/{domain_id}', [BoMenuCompletionController::class, 'domainsUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/domains/{domain_id}', [BoMenuCompletionController::class, 'domainsDestroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/domains/{domain_id}/verify', [BoMenuCompletionController::class, 'domainsVerify'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/members', [BoMenuCompletionController::class, 'membersIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/members', [BoMenuCompletionController::class, 'membersStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/members/{member_id}', [BoMenuCompletionController::class, 'membersShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/members/{member_id}', [BoMenuCompletionController::class, 'membersUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/members/{member_id}/status', [BoMenuCompletionController::class, 'membersStatus'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/monitoring', [BoMenuCompletionController::class, 'tenantMonitoring'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/usage', [BoMenuCompletionController::class, 'tenantUsage'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/sync-logs', [BoMenuCompletionController::class, 'tenantSyncLogs'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/admin-users', [AdminUserController::class, 'tenantIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/admin-users', [AdminUserController::class, 'tenantStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:permission_change']);
Route::get('/admin/tenant/admin-users/{admin_user_id}', [AdminUserController::class, 'tenantShow'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/admin-users/{admin_user_id}', [AdminUserController::class, 'tenantUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:permission_change']);
Route::delete('/admin/tenant/admin-users/{admin_user_id}', [AdminUserController::class, 'tenantDestroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:delete_user']);
Route::get('/admin/tenant/roles', [AdminRoleController::class, 'tenantIndex'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/roles', [AdminRoleController::class, 'tenantStore'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:role_change']);
Route::patch('/admin/tenant/roles/{role_id}', [AdminRoleController::class, 'tenantUpdate'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:role_change']);
Route::delete('/admin/tenant/roles/{role_id}', [AdminRoleController::class, 'tenantDestroy'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:role_change']);
Route::get('/admin/tenant/orders', [TenantCommerceController::class, 'orders'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/orders/{order_id}', [TenantCommerceController::class, 'order'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/orders/{order_id}', [TenantCommerceController::class, 'updateOrder'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/orders/{order_id}/cancel', [TenantCommerceController::class, 'cancelOrder'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/orders/{order_id}/refund', [TenantCommerceController::class, 'refundOrder'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/tickets', [TenantCommerceController::class, 'tickets'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/tickets/{ticket_id}', [TenantCommerceController::class, 'ticket'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/wallets', [TenantCommerceController::class, 'wallets'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/wallets/{wallet_id}', [TenantCommerceController::class, 'wallet'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/wallets/{wallet_id}/ledger', [TenantCommerceController::class, 'walletLedger'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/wallets/{wallet_id}/adjust', [TenantCommerceController::class, 'adjustWallet'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:wallet_adjust']);
Route::get('/admin/tenant/topups', [TenantCommerceController::class, 'topups'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/topups/{topup_id}', [TenantCommerceController::class, 'topup'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/topups/{topup_id}/approve', [TenantCommerceController::class, 'approveTopup'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:topup_approve']);
Route::post('/admin/tenant/topups/{topup_id}/reject', [TenantCommerceController::class, 'rejectTopup'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/topups/{topup_id}/cancel', [TenantCommerceController::class, 'cancelTopup'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/reward-claims', [TenantRewardClaimController::class, 'index'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/winners/games', [TenantRewardWinnersController::class, 'winnerGames'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/winners', [TenantRewardWinnersController::class, 'winners'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/reward-claims/{claim_id}', [TenantRewardClaimController::class, 'show'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/reward-claims/{claim_id}/approve', [TenantRewardClaimController::class, 'approve'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:payout_approve']);
Route::post('/admin/tenant/reward-claims/{claim_id}/reject', [TenantRewardClaimController::class, 'reject'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/reward-claims/{claim_id}/pay', [TenantRewardClaimController::class, 'pay'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:payout_approve']);
Route::get('/admin/tenant/agents', [TenantGrowthController::class, 'agents'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/agents', [TenantGrowthController::class, 'createAgent'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/agents/{agent_id}', [TenantGrowthController::class, 'agent'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/agents/{agent_id}', [TenantGrowthController::class, 'updateAgent'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/agents/{agent_id}/quotas', [TenantGrowthController::class, 'updateAgentQuotas'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-programs', [TenantGrowthController::class, 'affiliatePrograms'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/affiliate-programs', [TenantGrowthController::class, 'createAffiliateProgram'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-programs/{affiliate_program_id}', [TenantGrowthController::class, 'affiliateProgram'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/affiliate-programs/{affiliate_program_id}', [TenantGrowthController::class, 'updateAffiliateProgram'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/affiliate-programs/{affiliate_program_id}', [TenantGrowthController::class, 'archiveAffiliateProgram'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-links', [TenantGrowthController::class, 'affiliateLinks'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/affiliate-links', [TenantGrowthController::class, 'createAffiliateLink'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-links/{affiliate_link_id}', [TenantGrowthController::class, 'affiliateLink'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/affiliate-links/{affiliate_link_id}', [TenantGrowthController::class, 'updateAffiliateLink'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/affiliate-links/{affiliate_link_id}', [TenantGrowthController::class, 'archiveAffiliateLink'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-attributions', [TenantGrowthController::class, 'affiliateAttributions'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliate-attributions/{attribution_id}', [TenantGrowthController::class, 'affiliateAttribution'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliates', [TenantGrowthController::class, 'affiliates'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/affiliates', [TenantGrowthController::class, 'createAffiliate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/affiliates/{affiliate_id}', [TenantGrowthController::class, 'affiliate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/affiliates/{affiliate_id}', [TenantGrowthController::class, 'updateAffiliate'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/commission-rules', [TenantGrowthController::class, 'commissionRules'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/commission-rules', [TenantGrowthController::class, 'createCommissionRule'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/commission-rules/{commission_rule_id}', [TenantGrowthController::class, 'commissionRule'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::patch('/admin/tenant/commission-rules/{commission_rule_id}', [TenantGrowthController::class, 'updateCommissionRule'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::delete('/admin/tenant/commission-rules/{commission_rule_id}', [TenantGrowthController::class, 'archiveCommissionRule'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/commission-transactions', [TenantGrowthController::class, 'commissionTransactions'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/commission-transactions/{commission_id}', [TenantGrowthController::class, 'commissionTransaction'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/commission-transactions/{commission_id}/approve', [TenantGrowthController::class, 'approveCommissionTransaction'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/payouts', [TenantGrowthController::class, 'payouts'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/payouts', [TenantGrowthController::class, 'createPayout'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/payouts/{payout_id}/approve', [TenantGrowthController::class, 'approvePayout'])
    ->middleware(['admin.auth', 'admin.scope:tenant', 'support.block:payout_approve']);
Route::get('/admin/tenant/reports/{report_key}', [ReportController::class, 'tenantReport'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::post('/admin/tenant/reports/{report_key}/exports', [ReportController::class, 'createTenantExport'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/export-jobs/{export_job_id}', [ReportController::class, 'tenantExportJob'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);
Route::get('/admin/tenant/export-jobs/{export_job_id}/download', [ReportController::class, 'tenantDownload'])
    ->middleware(['admin.auth', 'admin.scope:tenant']);

Route::get('/partner-sync/allocations', [PartnerSyncController::class, 'allocations']);
Route::post('/partner-sync/events', [PartnerSyncController::class, 'events']);

Route::post('/webhooks/payments/{provider}', [WebhookController::class, 'payment']);
Route::post('/webhooks/topups/{provider}', [WebhookController::class, 'topup']);
