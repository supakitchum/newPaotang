<?php

namespace Database\Seeders;

use App\Models\AdminMenu;
use App\Models\Permission;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultRbacMenuSeeder extends Seeder
{
    public function run(): void
    {
        $now = now();

        Permission::query()->upsert(
            array_map(fn (array $permission): array => [
                'id' => $this->stableId('per', $permission['scope_type'], $permission['code']),
                'scope_type' => $permission['scope_type'],
                'code' => $permission['code'],
                'name' => $permission['name'],
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ], $this->permissions()),
            ['scope_type', 'code'],
            ['name', 'status', 'updated_at'],
        );

        AdminMenu::query()->upsert(
            array_map(fn (array $menu): array => [
                'id' => $this->stableId('men', $menu['scope_type'], $menu['code']),
                'scope_type' => $menu['scope_type'],
                'parent_id' => isset($menu['parent_code'])
                    ? $this->stableId('men', $menu['scope_type'], $menu['parent_code'])
                    : null,
                'code' => $menu['code'],
                'label' => $this->labelFor($menu['scope_type'], $menu['code']),
                'route' => $menu['route'],
                'category' => $this->categoryFor($menu['scope_type'], $menu['code']),
                'icon' => $this->iconFor($menu['scope_type'], $menu['code']),
                'required_permission_code' => $menu['required_permission_code'],
                'sort_order' => $menu['sort_order'],
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ], $this->menus()),
            ['scope_type', 'code'],
            ['parent_id', 'label', 'route', 'category', 'icon', 'required_permission_code', 'sort_order', 'status', 'updated_at'],
        );

        AdminMenu::query()
            ->where('scope_type', 'central')
            ->whereIn('code', ['master_stock', 'stock_recall', 'partner_provisioning'])
            ->delete();

        AdminMenu::query()
            ->where('scope_type', 'tenant')
            ->where('code', 'stock_sync')
            ->delete();

        Permission::query()
            ->where('scope_type', 'tenant')
            ->where('code', 'stock.sync')
            ->delete();

        $this->grantCentralDashboardMenusToDefaultRoles($now);
        $this->grantCentralMaintenanceToSuperAdmins($now);
        $this->grantCentralTelegramNotificationsToSuperAdmins($now);
        $this->grantCentralStorageConnectionsToSuperAdmins($now);
        $this->grantCentralTranslationsToRoles($now);
        $this->grantCentralRewardEntryToRoles($now);
        $this->grantCentralLotteryUploaderToRoles($now);
        $this->grantSalePricePermissionsToDefaultRoles($now);
        $this->grantWinnerMenuToPlatformOwner($now);
        $this->grantTenantWinnerMenuToPartnerOwners($now);
        $this->grantRewardRiskToRestrictedOwnerRoles($now);
        $this->grantTenantMaintenanceToPartnerOwners($now);
        $this->grantTenantAnnouncementsToPartnerOwners($now);
        $this->grantTenantActivitiesToPartnerOwners($now);
        $this->grantTenantLineNotificationsToPartnerOwners($now);
        $this->grantTenantCustomerNotificationsToPartnerOwners($now);
        $this->grantTenantSocialLoginToPartnerOwners($now);
        $this->grantTenantSmsOtpToPartnerOwners($now);
        $this->grantTenantPasswordResetToPartnerOwners($now);
        $this->grantTenantCustomerSupportToPartnerOwners($now);
        $this->ensureTenantCustomerSupportRoles($now);
    }

    /**
     * @return array<int, array{scope_type: string, code: string, name: string}>
     */
    public function permissions(): array
    {
        return [
            ...$this->scopedPermissions('central', [
                'dashboard.view' => 'View central dashboard',
                'game.view' => 'View games',
                'game.create' => 'Create games',
                'game.update' => 'Update games',
                'game.close' => 'Close games',
                'game.reward' => 'Manage game reward state',
                'reward.view' => 'View reward results',
                'reward.create' => 'Record reward results',
                'reward.verify' => 'Verify reward summaries',
                'reward.publish' => 'Publish rewards',
                'reward.correct' => 'Correct published rewards through correction flow',
                'reward.audit' => 'View reward audit',
                'reward_risk.view' => 'View reward risk assessments',
                'reward_risk.manage' => 'Manage reward risk assessment settings',
                'reward_entry.view' => 'View central reward entry sessions',
                'reward_entry.submit' => 'Submit independent reward entry results',
                'reward_entry.resolve' => 'Resolve reward entry submissions into final reward results',
                'price_rule.view' => 'View central sale price rules',
                'price_rule.manage' => 'Manage central sale price rules',
                'stock.view' => 'View stock manager',
                'stock.generate' => 'Generate/import stock manager',
                'stock.allocate' => 'Allocate stock to partners',
                'stock.recall' => 'Recall allocated stock',
                'stock.export' => 'Export stock data',
                'partner.view' => 'View partners',
                'partner.create' => 'Create partners',
                'partner.update' => 'Update partners',
                'partner.suspend' => 'Suspend partners',
                'partner.api.manage' => 'Manage partner API clients',
                'partner.quota.manage' => 'Manage partner quotas',
                'partner.provision' => 'Provision partner tenant defaults',
                'partner.monitoring.view' => 'View partner monitoring profile and health',
                'partner.monitoring.manage' => 'Manage partner monitoring profile',
                'partner.usage.view' => 'View partner usage meters',
                'partner.usage.manage' => 'Manage partner usage meters and limits',
                'partner.billing.view' => 'View partner billing bindings',
                'partner.billing.manage' => 'Manage partner billing plans and bindings',
                'partner.alert.view' => 'View partner alert policies and events',
                'partner.alert.manage' => 'Manage partner alert policies and event states',
                'settlement.view' => 'View settlements',
                'settlement.approve' => 'Approve settlements',
                'report.view' => 'View central reports',
                'admin_user.manage' => 'Manage central admin users',
                'role.manage' => 'Manage central roles',
                'menu.manage' => 'Manage central menus',
                'audit.view' => 'View central audit logs',
                'system.settings.manage' => 'Manage platform settings',
                'asset.manage' => 'Manage central asset upload intents',
                'support_access.audit' => 'View support access audits',
                'telegram_notification.view' => 'View Telegram notification settings',
                'telegram_notification.manage' => 'Manage Telegram notification settings and routes',
                'storage_connection.view' => 'View platform object storage connection settings',
                'storage_connection.manage' => 'Manage platform object storage connection settings',
                'translation.view' => 'View system translation center',
                'translation.edit' => 'Edit system translation drafts',
                'translation.request_deploy' => 'Submit translation deploy requests',
                'translation.approve_deploy' => 'Preview, approve, or reject translation deploy requests',
            ]),
            ...$this->scopedPermissions('tenant', [
                'dashboard.view' => 'View tenant dashboard',
                'stock.view' => 'View tenant virtual stock',
                'stock.export' => 'Export tenant stock',
                'reservation.view' => 'View reservations',
                'reservation.cancel' => 'Cancel reservations',
                'order.view' => 'View orders',
                'order.update' => 'Update orders',
                'order.cancel' => 'Cancel orders',
                'order.refund' => 'Refund orders',
                'customer.view' => 'View customers',
                'customer.create' => 'Create customers',
                'customer.update' => 'Update customers',
                'customer.suspend' => 'Suspend or disable customers',
                'customer_notification.view' => 'View customer notification history',
                'customer_notification.send' => 'Send notifications to tenant customers',
                'support_ticket.view_assigned' => 'View assigned customer support tickets',
                'support_ticket.reply_assigned' => 'Reply to assigned customer support tickets',
                'support_ticket.close_assigned' => 'Close assigned customer support tickets',
                'support_ticket.view_all' => 'View all customer support tickets',
                'support_ticket.assign' => 'Assign customer support tickets',
                'support_agent.manage' => 'Manage customer support agents and settings',
                'support_faq.view' => 'View customer support FAQs',
                'support_faq.manage' => 'Manage customer support categories and FAQs',
                'support_report.view' => 'View customer support reports',
                'customer_password_reset.view' => 'View customer password reset requests',
                'customer_password_reset.manage' => 'Issue customer password reset links',
                'wallet.view' => 'View wallets',
                'wallet.adjust' => 'Adjust wallet through audited ledger flow',
                'topup.view' => 'View topups',
                'topup.approve' => 'Approve topups',
                'topup.reject' => 'Reject topups',
                'topup.cancel' => 'Cancel topups',
                'ticket.view' => 'View tickets',
                'reward_claim.view' => 'View reward cashout claims',
                'reward_claim.approve' => 'Approve reward cashout claims',
                'reward_claim.reject' => 'Reject reward cashout claims',
                'reward_claim.pay' => 'Pay reward cashout claims',
                'reward_risk.view' => 'View reward risk assessments',
                'reward_risk.manage' => 'Manage reward risk assessment settings',
                'agent.view' => 'View agents',
                'agent.create' => 'Create agents',
                'agent.update' => 'Update agents',
                'agent.quota.manage' => 'Manage agent quotas',
                'price_rule.view' => 'View tenant price rules',
                'price_rule.manage' => 'Manage tenant price rules',
                'payment_settings.view' => 'View tenant payment settings and channels',
                'payment_settings.manage' => 'Manage tenant payment settings and channels',
                'affiliate.view' => 'View affiliate data',
                'affiliate.create' => 'Create affiliate records',
                'affiliate.update' => 'Update affiliate records',
                'affiliate_name_review.view' => 'View affiliate store name review requests',
                'affiliate_name_review.manage' => 'Approve or reject affiliate store names',
                'affiliate_tier.view' => 'View affiliate tiers',
                'affiliate_tier.manage' => 'Manage affiliate tier benefits',
                'affiliate_tier_campaign.view' => 'View affiliate tier campaigns',
                'affiliate_tier_campaign.manage' => 'Manage and finalize affiliate tier campaigns',
                'affiliate_program.view' => 'View affiliate programs',
                'affiliate_program.manage' => 'Manage affiliate programs',
                'affiliate_link.view' => 'View affiliate links',
                'affiliate_link.manage' => 'Manage affiliate links',
                'affiliate_attribution.view' => 'View affiliate attributions',
                'commission.view' => 'View commissions',
                'commission.approve' => 'Approve commissions',
                'commission_rule.view' => 'View commission rules',
                'commission_rule.manage' => 'Manage commission rules',
                'payout.manage' => 'Manage payouts',
                'report.view' => 'View tenant reports',
                'monitoring.view' => 'View tenant monitoring and health',
                'usage.view' => 'View tenant usage meters',
                'sync_log.view' => 'View sync logs',
                'seo.view' => 'View SEO settings',
                'seo.update' => 'Update SEO settings',
                'seo.redirect.manage' => 'Manage tenant redirects',
                'announcement.view' => 'View tenant announcements',
                'announcement.manage' => 'Manage tenant announcements',
                'line_notification.view' => 'View tenant LINE notification settings',
                'line_notification.manage' => 'Manage LINE notification settings and templates',
                'social_login.view' => 'View tenant social login provider settings',
                'social_login.manage' => 'Manage tenant social login provider settings',
                'sms_otp.view' => 'View tenant SMS OTP provider settings',
                'sms_otp.manage' => 'Manage tenant SMS OTP provider settings',
                'activity.view' => 'View tenant activities',
                'activity.manage' => 'Manage tenant activities',
                'maintenance.view' => 'View maintenance settings',
                'maintenance.update' => 'Update maintenance settings',
                'maintenance.schedule' => 'Schedule maintenance',
                'maintenance.bypass' => 'Bypass maintenance',
                'support_access.request' => 'Request support access',
                'support_access.approve' => 'Approve support access',
                'support_access.impersonate_customer' => 'Impersonate customer with limits',
                'support_access.impersonate_admin' => 'Impersonate tenant admin with approval',
                'support_access.elevated_action' => 'Request or use elevated support action',
                'support_access.audit' => 'View support access audit',
                'admin_user.manage' => 'Manage tenant admin users',
                'role.manage' => 'Manage tenant roles',
                'menu.manage' => 'Manage tenant menus',
                'settings.view' => 'View tenant settings',
                'settings.manage' => 'Manage tenant settings',
                'asset.manage' => 'Manage tenant asset upload intents',
                'audit.view' => 'View tenant audit logs',
            ]),
        ];
    }

    /**
     * @return array<int, array{scope_type: string, code: string, required_permission_code: string, route: string|null, sort_order: int, parent_code?: string}>
     */
    public function menus(): array
    {
        return [
            ...$this->scopedMenus('central', [
                'dashboard' => 'dashboard.view',
                'dashboard_sales' => 'dashboard.view',
                'dashboard_partner' => 'dashboard.view',
                'dashboard_wallet' => 'dashboard.view',
                'dashboard_payout' => 'dashboard.view',
                'dashboard_monitor' => 'dashboard.view',
                'games' => 'game.view',
                'reward_entry' => 'reward_entry.view',
                'rewards' => 'reward.view',
                'winners' => 'reward.view',
                'reward_risk' => 'reward_risk.view',
                'prize_checking' => 'reward.view',
                'sale_price_rules' => 'price_rule.view',
                'reward_payout_rules' => 'price_rule.view',
                'lottery_images' => 'asset.manage',
                'stock_generation' => 'stock.generate',
                'stock_settings' => 'stock.generate',
                'partners' => 'partner.view',
                'maintenance' => 'partner.view',
                'partner_quotas' => 'partner.quota.manage',
                'partner_monitoring' => 'partner.monitoring.view',
                'partner_usage' => 'partner.usage.view',
                'allocations' => 'stock.allocate',
                'billing_plans' => 'partner.billing.manage',
                'alert_policies' => 'partner.alert.manage',
                'alert_events' => 'partner.alert.view',
                'reports' => 'report.view',
                'settlement' => 'settlement.view',
                'webhook_logs' => 'audit.view',
                'audit_logs' => 'audit.view',
                'admin_users' => 'admin_user.manage',
                'roles_permissions' => 'role.manage',
                'menu_management' => 'menu.manage',
                'telegram_notifications' => 'telegram_notification.view',
                'storage_connections' => 'storage_connection.view',
                'translations' => 'translation.view',
                'system_settings' => 'system.settings.manage',
            ]),
            ...$this->scopedMenus('tenant', [
                'dashboard' => 'dashboard.view',
                'local_stock' => 'stock.view',
                'price_rules' => 'price_rule.view',
                'sale_price_rules' => 'price_rule.view',
                'reservations' => 'reservation.view',
                'orders' => 'order.view',
                'customers' => 'customer.view',
                'wallets' => 'wallet.view',
                'topups' => 'topup.view',
                'tickets' => 'ticket.view',
                'exchange_reward' => 'reward_claim.view',
                'winners' => 'reward_claim.view',
                'reward_risk' => 'reward_risk.view',
                'agents' => 'agent.view',
                'agent_quotas' => 'agent.quota.manage',
                'payment_settings' => 'payment_settings.view',
                'affiliate' => 'affiliate.view',
                'affiliate_programs' => 'affiliate_program.view',
                'affiliate_accounts' => 'affiliate.view',
                'affiliate_store_name_requests' => 'affiliate_name_review.view',
                'affiliate_tiers' => 'affiliate_tier.view',
                'affiliate_tier_campaigns' => 'affiliate_tier_campaign.view',
                'affiliate_links' => 'affiliate_link.view',
                'affiliate_attributions' => 'affiliate_attribution.view',
                'commission_rules' => 'commission_rule.view',
                'announcements' => 'announcement.view',
                'customer_notifications' => 'customer_notification.view',
                'customer_support' => 'support_ticket.view_assigned',
                'line_notifications' => 'line_notification.view',
                'social_login' => 'social_login.view',
                'sms_otp' => 'sms_otp.view',
                'password_reset_requests' => 'customer_password_reset.view',
                'activities' => 'activity.view',
                'activity_claims' => 'activity.view',
                'seo_settings' => 'seo.view',
                'maintenance' => 'maintenance.view',
                'support_access_logs' => 'support_access.audit',
                'commission_transactions' => 'commission.view',
                'payouts' => 'payout.manage',
                'reports' => 'report.view',
                'monitoring' => 'monitoring.view',
                'usage' => 'usage.view',
                'sync_logs' => 'sync_log.view',
                'audit_logs' => 'audit.view',
                'admin_users' => 'admin_user.manage',
                'roles_permissions' => 'role.manage',
                'menu_management' => 'menu.manage',
                'settings' => 'settings.view',
            ]),
        ];
    }

    /**
     * @param array<string, string> $permissions
     * @return array<int, array{scope_type: string, code: string, name: string}>
     */
    private function scopedPermissions(string $scopeType, array $permissions): array
    {
        $rows = [];

        foreach ($permissions as $code => $name) {
            $rows[] = [
                'scope_type' => $scopeType,
                'code' => $code,
                'name' => $name,
            ];
        }

        return $rows;
    }

    /**
     * @param array<string, string> $menus
     * @return array<int, array{scope_type: string, code: string, required_permission_code: string, route: string|null, sort_order: int, parent_code?: string}>
     */
    private function scopedMenus(string $scopeType, array $menus): array
    {
        $rows = [];
        $sortOrder = 10;

        foreach ($menus as $code => $permissionCode) {
            $row = [
                'scope_type' => $scopeType,
                'code' => $code,
                'required_permission_code' => $permissionCode,
                'route' => $this->routeFor($scopeType, $code),
                'sort_order' => $sortOrder,
            ];

            if ($scopeType === 'central' && str_starts_with($code, 'dashboard_')) {
                $row['parent_code'] = 'dashboard';
            }

            if ($scopeType === 'tenant' && in_array($code, $this->tenantAffiliateChildMenuCodes(), true)) {
                $row['parent_code'] = 'affiliate';
            }

            $rows[] = $row;

            $sortOrder += 10;
        }

        return $rows;
    }

    private function routeFor(string $scopeType, string $code): ?string
    {
        return match ($scopeType.':'.$code) {
            'central:dashboard' => '/admin/central/dashboard',
            'central:dashboard_sales' => '/admin/central/dashboard/sales',
            'central:dashboard_partner' => '/admin/central/dashboard/partner',
            'central:dashboard_wallet' => '/admin/central/dashboard/wallet',
            'central:dashboard_payout' => '/admin/central/dashboard/payout',
            'central:dashboard_monitor' => '/admin/central/dashboard/monitor',
            'central:games' => '/admin/central/games',
            'central:reward_entry' => '/admin/central/reward-entry',
            'central:winners' => '/admin/central/winners',
            'central:reward_risk' => '/admin/central/reward-risk',
            'tenant:winners' => '/admin/tenant/winners',
            'tenant:reward_risk' => '/admin/tenant/reward-risk',
            'central:rewards',
            'central:prize_checking' => '/admin/central/rewards',
            'central:sale_price_rules' => '/admin/central/sale-price-rules',
            'central:reward_payout_rules' => '/admin/central/reward-payout-rules',
            'central:lottery_images' => '/admin/central/lottery-images',
            'central:stock_generation' => '/admin/central/stock',
            'central:stock_settings' => '/admin/central/stock-settings',
            'central:partners' => '/admin/central/partners',
            'central:maintenance' => '/admin/central/maintenance',
            'central:partner_quotas',
            'central:partner_monitoring',
            'central:partner_usage',
            'central:billing_plans',
            'central:alert_policies',
            'central:alert_events' => '/admin/central/partners',
            'central:allocations' => '/admin/central/allocations',
            'central:reports' => '/admin/central/reports',
            'central:settlement' => '/admin/central/settlements',
            'central:webhook_logs',
            'central:audit_logs' => '/admin/central/audit-logs',
            'central:admin_users',
            'central:roles_permissions',
            'central:menu_management',
            'central:telegram_notifications' => '/admin/central/telegram-notifications',
            'central:storage_connections' => '/admin/central/storage-connections',
            'central:translations' => '/admin/central/translations',
            'central:system_settings' => '/admin/central/dashboard',
            'tenant:dashboard' => '/admin/tenant/dashboard',
            'tenant:local_stock' => '/admin/tenant/stock',
            'tenant:price_rules' => '/admin/tenant/settings',
            'tenant:sale_price_rules' => '/admin/tenant/sale-price-rules',
            'tenant:reservations' => '/admin/tenant/reservations',
            'tenant:orders' => '/admin/tenant/orders',
            'tenant:customers' => '/admin/tenant/settings',
            'tenant:wallets' => '/admin/tenant/wallets',
            'tenant:topups' => '/admin/tenant/topups',
            'tenant:tickets' => '/admin/tenant/tickets',
            'tenant:exchange_reward' => '/admin/tenant/exchange-reward',
            'tenant:agents',
            'tenant:agent_quotas' => '/admin/tenant/growth/agents',
            'tenant:payment_settings' => '/admin/tenant/payment-settings',
            'tenant:announcements' => '/admin/tenant/announcements',
            'tenant:customer_notifications' => '/admin/tenant/customer-notifications',
            'tenant:customer_support' => '/admin/tenant/support',
            'tenant:line_notifications' => '/admin/tenant/line-notifications',
            'tenant:social_login' => '/admin/tenant/social-login',
            'tenant:sms_otp' => '/admin/tenant/sms-otp',
            'tenant:password_reset_requests' => '/admin/tenant/password-reset-requests',
            'tenant:activities' => '/admin/tenant/activities',
            'tenant:activity_claims' => '/admin/tenant/activity-claims',
            'tenant:affiliate' => '/admin/tenant/growth/affiliates',
            'tenant:affiliate_programs' => '/admin/tenant/growth/affiliate-programs',
            'tenant:affiliate_accounts' => '/admin/tenant/growth/affiliates',
            'tenant:affiliate_store_name_requests' => '/admin/tenant/growth/affiliate-store-name-requests',
            'tenant:affiliate_tiers' => '/admin/tenant/growth/affiliate-tiers',
            'tenant:affiliate_tier_campaigns' => '/admin/tenant/growth/affiliate-tier-campaigns',
            'tenant:affiliate_links' => '/admin/tenant/growth/affiliate-links',
            'tenant:affiliate_attributions' => '/admin/tenant/growth/attributions',
            'tenant:commission_rules' => '/admin/tenant/growth/commission-rules',
            'tenant:commission_transactions' => '/admin/tenant/growth/commission-transactions',
            'tenant:payouts' => '/admin/tenant/growth/payouts',
            'tenant:seo_settings' => '/admin/tenant/seo',
            'tenant:maintenance' => '/admin/tenant/maintenance',
            'tenant:support_access_logs' => '/admin/tenant/support-access',
            'tenant:reports' => '/admin/tenant/reports',
            'tenant:monitoring',
            'tenant:usage' => '/admin/tenant/reports',
            'tenant:sync_logs' => '/admin/tenant/sync-logs',
            'tenant:audit_logs' => '/admin/tenant/audit-logs',
            'tenant:admin_users',
            'tenant:roles_permissions',
            'tenant:menu_management',
            'tenant:settings' => '/admin/tenant/settings',
            default => null,
        };
    }

    private function stableId(string $prefix, string $scopeType, string $code): string
    {
        return $prefix.'_'.substr($scopeType, 0, 1).'_'.substr(sha1($scopeType.':'.$code), 0, 20);
    }

    private function labelFor(string $scopeType, string $code): string
    {
        if (str_starts_with($code, 'dashboard_')) {
            return str($code)->after('dashboard_')->replace('_', ' ')->title()->toString();
        }

        if ($code === 'stock_generation') {
            return 'Stock Manager';
        }

        if ($code === 'local_stock') {
            return 'Tenant Stock';
        }

        if ($code === 'partners') {
            return 'Partner/Tenant';
        }

        if ($code === 'exchange_reward') {
            return 'Exchange Reward';
        }

        if ($scopeType === 'central' && $code === 'maintenance') {
            return 'Central Maintenance';
        }

        if ($code === 'line_notifications') {
            return 'LINE Notifications';
        }

        if ($code === 'customer_notifications') {
            return 'Public Relations';
        }

        if ($code === 'customer_support') {
            return 'Customer Support';
        }

        if ($code === 'social_login') {
            return 'Social Login';
        }

        if ($code === 'sms_otp') {
            return 'SMS OTP';
        }

        if ($code === 'password_reset_requests') {
            return 'Password Reset Requests';
        }

        if ($code === 'telegram_notifications') {
            return 'Telegram Notifications';
        }

        if ($code === 'storage_connections') {
            return 'Storage Connections';
        }

        if ($code === 'translations') {
            return 'Translation Center';
        }

        if ($code === 'reward_entry') {
            return 'Result Entry';
        }

        if ($code === 'reward_risk') {
            return 'Reward Risk Assessment';
        }

        if ($scopeType === 'tenant' && $code === 'affiliate') {
            return 'Affiliate';
        }

        return str($code)->replace('_', ' ')->title()->toString();
    }

    private function categoryFor(string $scopeType, string $code): string
    {
        if ($code === 'dashboard' || str_starts_with($code, 'dashboard_')) {
            return 'Dashboard';
        }

        return match ($scopeType.':'.$code) {
            'central:games',
            'central:rewards',
            'central:winners',
            'central:reward_risk',
            'central:prize_checking',
            'central:sale_price_rules',
            'central:reward_payout_rules',
            'central:lottery_images',
            'central:stock_generation',
            'central:stock_settings',
            'central:reward_entry',
            'central:allocations' => 'Lottery Operations',
            'central:translations' => 'Review Queue',
            'central:partners',
            'central:maintenance',
            'central:partner_quotas',
            'central:partner_monitoring',
            'central:partner_usage',
            'central:billing_plans',
            'central:alert_policies',
            'central:alert_events' => 'Partner Operations',
            'central:reports',
            'central:settlement' => 'Finance And Reports',
            'central:telegram_notifications',
            'central:storage_connections' => 'Plugins',
            'central:webhook_logs',
            'central:audit_logs',
            'central:admin_users',
            'central:roles_permissions',
            'central:menu_management',
            'central:system_settings' => 'Administration',
            'tenant:local_stock',
            'tenant:price_rules',
            'tenant:sale_price_rules',
            'tenant:reservations',
            'tenant:orders',
            'tenant:customers',
            'tenant:wallets',
            'tenant:tickets',
            'tenant:winners',
            'tenant:payment_settings' => 'Store Operations',
            'tenant:reward_risk' => 'Store Operations',
            'tenant:customer_notifications' => 'Store Operations',
            'tenant:customer_support' => 'Store Operations',
            'tenant:line_notifications',
            'tenant:social_login',
            'tenant:sms_otp' => 'Plugins',
            'tenant:password_reset_requests',
            'tenant:topups',
            'tenant:exchange_reward',
            'tenant:activity_claims',
            'tenant:support_access_logs' => 'Review Queue',
            'tenant:agents',
            'tenant:agent_quotas',
            'tenant:announcements',
            'tenant:activities',
            'tenant:affiliate',
            'tenant:affiliate_programs',
            'tenant:affiliate_accounts',
            'tenant:affiliate_links',
            'tenant:affiliate_attributions',
            'tenant:commission_rules',
            'tenant:commission_transactions',
            'tenant:payouts' => 'Growth',
            'tenant:seo_settings',
            'tenant:maintenance',
            'tenant:reports',
            'tenant:monitoring',
            'tenant:usage',
            'tenant:sync_logs',
            'tenant:audit_logs' => 'Operations Control',
            'tenant:admin_users',
            'tenant:roles_permissions',
            'tenant:menu_management',
            'tenant:settings' => 'Administration',
            default => 'Administration',
        };
    }

    private function iconFor(string $scopeType, string $code): string
    {
        return match (true) {
            $code === 'dashboard' => 'ri-dashboard-line',
            $code === 'dashboard_sales' => 'ri-line-chart-line',
            $code === 'dashboard_partner' => 'ri-building-4-line',
            $code === 'dashboard_wallet' => 'ri-wallet-3-line',
            $code === 'dashboard_payout' => 'ri-bank-card-line',
            $code === 'dashboard_monitor' => 'ri-pulse-line',
            $code === 'reward_risk' => 'ri-radar-line',
            str_contains($code, 'stock') || str_contains($code, 'allocation') => 'ri-archive-stack-line',
            str_contains($code, 'image') => 'ri-image-2-line',
            str_contains($code, 'reward') || str_contains($code, 'prize') || str_contains($code, 'winner') => 'ri-trophy-line',
            str_contains($code, 'partner') => 'ri-building-4-line',
            str_contains($code, 'quota') => 'ri-speed-up-line',
            str_contains($code, 'billing') || str_contains($code, 'settlement') || str_contains($code, 'payout') => 'ri-bank-card-line',
            str_contains($code, 'alert') || str_contains($code, 'monitoring') => 'ri-notification-3-line',
            str_contains($code, 'customer_notification') => 'ri-notification-3-line',
            str_contains($code, 'customer_support') => 'ri-customer-service-2-line',
            str_contains($code, 'announcement') => 'ri-megaphone-line',
            str_contains($code, 'telegram') => 'ri-telegram-line',
            str_contains($code, 'storage') => 'ri-database-2-line',
            str_contains($code, 'translation') => 'ri-translate-2',
            str_contains($code, 'line_notification') => 'ri-line-line',
            str_contains($code, 'social_login') => 'ri-login-circle-line',
            str_contains($code, 'sms_otp') => 'ri-message-2-line',
            str_contains($code, 'password_reset') => 'ri-lock-password-line',
            str_contains($code, 'activity') => 'ri-gift-line',
            str_contains($code, 'report') || str_contains($code, 'usage') => 'ri-bar-chart-box-line',
            str_contains($code, 'audit') || str_contains($code, 'log') => 'ri-history-line',
            str_contains($code, 'admin_user') => 'ri-user-settings-line',
            str_contains($code, 'role') || str_contains($code, 'permission') => 'ri-shield-user-line',
            str_contains($code, 'menu') => 'ri-menu-2-line',
            str_contains($code, 'setting') || str_contains($code, 'seo') => 'ri-settings-3-line',
            str_contains($code, 'maintenance') => 'ri-tools-line',
            str_contains($code, 'support') => 'ri-customer-service-2-line',
            str_contains($code, 'order') || str_contains($code, 'ticket') => 'ri-receipt-line',
            str_contains($code, 'wallet') || str_contains($code, 'topup') || str_contains($code, 'payment') => 'ri-wallet-3-line',
            str_contains($code, 'agent') || str_contains($code, 'affiliate') || str_contains($code, 'commission') => 'ri-team-line',
            $scopeType === 'central' => 'ri-apps-2-line',
            default => 'ri-dashboard-line',
        };
    }

    /**
     * @return array<int, string>
     */
    private function tenantAffiliateChildMenuCodes(): array
    {
        return [
            'affiliate_programs',
            'affiliate_accounts',
            'affiliate_store_name_requests',
            'affiliate_tiers',
            'affiliate_tier_campaigns',
            'affiliate_links',
            'affiliate_attributions',
            'commission_rules',
            'commission_transactions',
            'payouts',
        ];
    }

    private function grantSalePricePermissionsToDefaultRoles(mixed $now): void
    {
        $roleScopes = [
            'central' => ['super_admin'],
            'tenant' => ['owner'],
        ];
        $menuScopes = [
            'central' => ['sale_price_rules', 'reward_payout_rules'],
            'tenant' => ['price_rules', 'sale_price_rules'],
        ];

        foreach ($roleScopes as $scopeType => $roleCodes) {
            $roles = DB::table('roles')
                ->where('scope_type', $scopeType)
                ->whereIn('code', $roleCodes)
                ->get(['id']);
            $roleIds = $roles->pluck('id')->all();

            if ($roleIds === []) {
                continue;
            }

            $permissionIds = DB::table('permissions')
                ->where('scope_type', $scopeType)
                ->whereIn('code', ['price_rule.view', 'price_rule.manage'])
                ->where('status', 'active')
                ->pluck('id')
                ->all();

            if ($permissionIds === []) {
                continue;
            }

            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $rows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($rows);

            $menuIds = DB::table('admin_menus')
                ->where('scope_type', $scopeType)
                ->whereIn('code', $menuScopes[$scopeType] ?? [])
                ->where('status', 'active')
                ->pluck('id')
                ->all();

            if ($menuIds !== []) {
                $menuRows = [];
                foreach ($roleIds as $roleId) {
                    foreach ($menuIds as $menuId) {
                        $menuRows[] = [
                            'role_id' => $roleId,
                            'menu_id' => $menuId,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }
                }

                DB::table('role_menus')->insertOrIgnore($menuRows);
            }

            $this->bumpPermissionCacheVersions($roleIds, $now);
        }
    }

    private function grantCentralDashboardMenusToDefaultRoles(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard.view')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->whereIn('code', ['dashboard', 'dashboard_sales', 'dashboard_partner', 'dashboard_wallet', 'dashboard_payout', 'dashboard_monitor'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantCentralMaintenanceToSuperAdmins(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['partner.view', 'partner.update'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'maintenance')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantCentralTelegramNotificationsToSuperAdmins(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['telegram_notification.view', 'telegram_notification.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'telegram_notifications')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantCentralStorageConnectionsToSuperAdmins(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['storage_connection.view', 'storage_connection.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'storage_connections')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantCentralTranslationsToRoles(mixed $now): void
    {
        $translatorRole = DB::table('roles')->where('id', 'rol_c_translator')->first();

        if ($translatorRole) {
            DB::table('roles')
                ->where('id', 'rol_c_translator')
                ->update([
                    'scope_type' => 'central',
                    'tenant_id' => null,
                    'code' => 'translator',
                    'name' => 'Translator / นักแปลภาษา',
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        } else {
            DB::table('roles')->insert([
                'id' => 'rol_c_translator',
                'scope_type' => 'central',
                'tenant_id' => null,
                'code' => 'translator',
                'name' => 'Translator / นักแปลภาษา',
                'status' => 'active',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $translatorRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->where('code', 'translator')
            ->pluck('id')
            ->all();

        $superAdminRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        $this->grantPermissionsToRoles($translatorRoleIds, ['translation.view', 'translation.edit', 'translation.request_deploy'], $now);
        $this->grantPermissionsToRoles($superAdminRoleIds, ['translation.view', 'translation.edit', 'translation.request_deploy', 'translation.approve_deploy'], $now);

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'translations')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        $roleIds = array_values(array_unique([...$translatorRoleIds, ...$superAdminRoleIds]));
        if ($roleIds !== [] && $menuIds !== []) {
            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $rows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($rows);
        }

        if ($roleIds !== []) {
            $this->bumpPermissionCacheVersions($roleIds, $now);
        }
    }

    private function grantCentralRewardEntryToRoles(mixed $now): void
    {
        $resultOfficerRole = DB::table('roles')->where('id', 'rol_c_result_officer')->first();

        if ($resultOfficerRole) {
            DB::table('roles')
                ->where('id', 'rol_c_result_officer')
                ->update([
                    'scope_type' => 'central',
                    'tenant_id' => null,
                    'code' => 'result_officer',
                    'name' => 'Result Officer / นักออกผล',
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        } else {
            DB::table('roles')->insert([
                'id' => 'rol_c_result_officer',
                'scope_type' => 'central',
                'tenant_id' => null,
                'code' => 'result_officer',
                'name' => 'Result Officer / นักออกผล',
                'status' => 'active',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $resultOfficerRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->where('code', 'result_officer')
            ->pluck('id')
            ->all();

        $superAdminRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        $this->grantPermissionsToRoles($resultOfficerRoleIds, ['reward_entry.view', 'reward_entry.submit'], $now);
        $this->grantPermissionsToRoles($superAdminRoleIds, ['reward_entry.view', 'reward_entry.submit', 'reward_entry.resolve'], $now);

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'reward_entry')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        $roleIds = array_values(array_unique([...$resultOfficerRoleIds, ...$superAdminRoleIds]));
        if ($roleIds !== [] && $menuIds !== []) {
            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $rows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($rows);
        }

        if ($roleIds !== []) {
            $this->bumpPermissionCacheVersions($roleIds, $now);
        }
    }

    private function grantCentralLotteryUploaderToRoles(mixed $now): void
    {
        $uploaderRole = DB::table('roles')->where('id', 'rol_c_lottery_uploader')->first();

        if ($uploaderRole) {
            DB::table('roles')
                ->where('id', 'rol_c_lottery_uploader')
                ->update([
                    'scope_type' => 'central',
                    'tenant_id' => null,
                    'code' => 'lottery_uploader',
                    'name' => 'Lottery Image Uploader / ผู้อัปโหลดรูปสลาก',
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        } else {
            DB::table('roles')->insert([
                'id' => 'rol_c_lottery_uploader',
                'scope_type' => 'central',
                'tenant_id' => null,
                'code' => 'lottery_uploader',
                'name' => 'Lottery Image Uploader / ผู้อัปโหลดรูปสลาก',
                'status' => 'active',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $uploaderRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->where('code', 'lottery_uploader')
            ->pluck('id')
            ->all();

        $superAdminRoleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        $this->revokePermissionsFromRoles($uploaderRoleIds, ['game.view']);
        $this->grantPermissionsToRoles($uploaderRoleIds, ['stock.view', 'asset.manage'], $now);
        $this->grantPermissionsToRoles($superAdminRoleIds, ['game.view', 'stock.view', 'asset.manage'], $now);

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'lottery_images')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        $roleIds = array_values(array_unique([...$uploaderRoleIds, ...$superAdminRoleIds]));
        if ($roleIds !== [] && $menuIds !== []) {
            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $rows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($rows);
        }

        if ($roleIds !== []) {
            $this->bumpPermissionCacheVersions($roleIds, $now);
        }
    }

    /**
     * @param array<int, string> $roleIds
     * @param array<int, string> $permissionCodes
     */
    private function grantPermissionsToRoles(array $roleIds, array $permissionCodes, mixed $now): void
    {
        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', $permissionCodes)
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds === []) {
            return;
        }

        $rows = [];
        foreach ($roleIds as $roleId) {
            foreach ($permissionIds as $permissionId) {
                $rows[] = [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        DB::table('role_permissions')->insertOrIgnore($rows);
    }

    /**
     * @param array<int, string> $roleIds
     * @param array<int, string> $permissionCodes
     */
    private function revokePermissionsFromRoles(array $roleIds, array $permissionCodes): void
    {
        if ($roleIds === [] || $permissionCodes === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', $permissionCodes)
            ->pluck('id')
            ->all();

        if ($permissionIds === []) {
            return;
        }

        DB::table('role_permissions')
            ->whereIn('role_id', $roleIds)
            ->whereIn('permission_id', $permissionIds)
            ->delete();
    }

    private function grantWinnerMenuToPlatformOwner(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->whereIn('code', ['super_admin'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'reward.view')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'winners')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantWinnerMenuToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['reward_claim.view', 'reward_claim.approve', 'reward_claim.reject'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['winners', 'exchange_reward'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantRewardRiskToRestrictedOwnerRoles(mixed $now): void
    {
        foreach ([
            'central' => ['super_admin'],
            'tenant' => ['owner', 'owner_partner'],
        ] as $scopeType => $roleCodes) {
            $roleQuery = DB::table('roles')
                ->where('scope_type', $scopeType)
                ->whereIn('code', $roleCodes);
            if ($scopeType === 'central') {
                $roleQuery->whereNull('tenant_id');
            }
            $roleIds = $roleQuery->pluck('id')->all();
            if ($roleIds === []) {
                continue;
            }

            $permissionIds = DB::table('permissions')
                ->where('scope_type', $scopeType)
                ->whereIn('code', ['reward_risk.view', 'reward_risk.manage'])
                ->where('status', 'active')
                ->pluck('id')
                ->all();
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }
            if ($permissionRows !== []) {
                DB::table('role_permissions')->insertOrIgnore($permissionRows);
            }

            $menuId = DB::table('admin_menus')
                ->where('scope_type', $scopeType)
                ->where('code', 'reward_risk')
                ->where('status', 'active')
                ->value('id');
            if ($menuId !== null) {
                DB::table('role_menus')->insertOrIgnore(array_map(fn (string $roleId): array => [
                    'role_id' => $roleId,
                    'menu_id' => (string) $menuId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $roleIds));
            }

            $this->bumpPermissionCacheVersions($roleIds, $now);
        }
    }

    private function grantTenantMaintenanceToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['maintenance.view', 'maintenance.update', 'maintenance.schedule', 'maintenance.bypass'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'maintenance')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantAnnouncementsToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['announcement.view', 'announcement.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'announcements')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantActivitiesToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['activity.view', 'activity.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['activities', 'activity_claims'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantLineNotificationsToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['line_notification.view', 'line_notification.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'line_notifications')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantCustomerNotificationsToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['customer_notification.view', 'customer_notification.send'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_notifications')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantCustomerSupportToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();
        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', [
                'support_ticket.view_assigned',
                'support_ticket.reply_assigned',
                'support_ticket.close_assigned',
                'support_ticket.view_all',
                'support_ticket.assign',
                'support_agent.manage',
                'support_faq.view',
                'support_faq.manage',
                'support_report.view',
            ])
            ->where('status', 'active')
            ->pluck('id')
            ->all();
        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_support')
            ->where('status', 'active')
            ->pluck('id')
            ->all();
        foreach ($roleIds as $roleId) {
            foreach ($permissionIds as $permissionId) {
                DB::table('role_permissions')->insertOrIgnore([
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
            foreach ($menuIds as $menuId) {
                DB::table('role_menus')->insertOrIgnore([
                    'role_id' => $roleId,
                    'menu_id' => $menuId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function ensureTenantCustomerSupportRoles(mixed $now): void
    {
        $permissionIdsByCode = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('status', 'active')
            ->whereIn('code', [
                'support_ticket.view_assigned',
                'support_ticket.reply_assigned',
                'support_ticket.close_assigned',
                'support_ticket.view_all',
                'support_ticket.assign',
                'support_agent.manage',
                'support_faq.view',
                'support_faq.manage',
                'support_report.view',
            ])
            ->pluck('id', 'code');
        $menuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_support')
            ->value('id');
        $roleIds = [];

        foreach (DB::table('partner_tenants')->pluck('id') as $tenantId) {
            $definitions = [
                'support' => [
                    'name' => 'Support',
                    'permissions' => [
                        'support_ticket.view_assigned',
                        'support_ticket.reply_assigned',
                        'support_ticket.close_assigned',
                    ],
                ],
                'master_support' => [
                    'name' => 'Master Support',
                    'permissions' => array_keys($permissionIdsByCode->all()),
                ],
            ];
            foreach ($definitions as $code => $definition) {
                $roleId = $this->stableId('rol', 'tenant:'.$tenantId, $code);
                $roleIds[] = $roleId;
                DB::table('roles')->updateOrInsert(
                    ['id' => $roleId],
                    [
                        'scope_type' => 'tenant',
                        'tenant_id' => $tenantId,
                        'code' => $code,
                        'name' => $definition['name'],
                        'status' => 'active',
                        'version' => 1,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ],
                );
                $allowedPermissionIds = collect($definition['permissions'])
                    ->map(fn (string $permissionCode): ?string => $permissionIdsByCode[$permissionCode] ?? null)
                    ->filter()
                    ->values()
                    ->all();
                $stalePermissionQuery = DB::table('role_permissions')->where('role_id', $roleId);
                $allowedPermissionIds === []
                    ? $stalePermissionQuery->delete()
                    : $stalePermissionQuery->whereNotIn('permission_id', $allowedPermissionIds)->delete();
                foreach ($definition['permissions'] as $permissionCode) {
                    $permissionId = $permissionIdsByCode[$permissionCode] ?? null;
                    if ($permissionId === null) {
                        continue;
                    }
                    DB::table('role_permissions')->insertOrIgnore([
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
                $staleMenuQuery = DB::table('role_menus')->where('role_id', $roleId);
                if ($menuId !== null) {
                    $staleMenuQuery->where('menu_id', '!=', $menuId)->delete();
                    DB::table('role_menus')->insertOrIgnore([
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                } else {
                    $staleMenuQuery->delete();
                }
            }
        }

        $this->bumpPermissionCacheVersions(array_values(array_unique($roleIds)), $now);
    }

    private function grantTenantSmsOtpToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['sms_otp.view', 'sms_otp.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'sms_otp')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantSocialLoginToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['social_login.view', 'social_login.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'social_login')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    private function grantTenantPasswordResetToPartnerOwners(mixed $now): void
    {
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner_partner', 'owner'])
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['customer_password_reset.view', 'customer_password_reset.manage'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        $menuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'password_reset_requests')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            $menuRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $menuRows[] = [
                        'role_id' => $roleId,
                        'menu_id' => $menuId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function bumpPermissionCacheVersions(array $roleIds, mixed $now): void
    {
        DB::table('admin_user_roles')
            ->whereIn('role_id', $roleIds)
            ->orderBy('admin_user_id')
            ->select(['admin_user_id', 'scope_id'])
            ->distinct()
            ->chunk(100, function ($rows) use ($now): void {
                foreach ($rows as $row) {
                    $keys = [
                        'admin_user_id' => (string) $row->admin_user_id,
                        'scope_id' => (string) $row->scope_id,
                    ];
                    $updated = DB::table('admin_permission_cache_versions')
                        ->where($keys)
                        ->update([
                            'version' => DB::raw('version + 1'),
                            'updated_at' => $now,
                        ]);

                    if ($updated > 0) {
                        continue;
                    }

                    DB::table('admin_permission_cache_versions')->insert([
                        ...$keys,
                        ...[
                            'id' => $this->permissionCacheVersionId((string) $row->admin_user_id, (string) $row->scope_id),
                            'version' => 2,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ],
                    ]);
                }
            });
    }

    private function permissionCacheVersionId(string $adminUserId, string $scopeId): string
    {
        return 'pcv_'.substr(sha1($adminUserId.':'.$scopeId), 0, 20);
    }
}
