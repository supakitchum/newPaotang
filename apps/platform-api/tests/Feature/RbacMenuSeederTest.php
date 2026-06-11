<?php

namespace Tests\Feature;

use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RbacMenuSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_default_permissions_seed_by_scope(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertSame(55, DB::table('permissions')->where('scope_type', 'central')->count());
        $this->assertSame(75, DB::table('permissions')->where('scope_type', 'tenant')->count());

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'partner.provision',
            'name' => 'Provision partner tenant defaults',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'tenant',
            'code' => 'support_access.impersonate_admin',
            'name' => 'Impersonate tenant admin with approval',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'price_rule.view',
            'name' => 'View central sale price rules',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'tenant',
            'code' => 'line_notification.manage',
            'name' => 'Manage LINE notification settings and templates',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'telegram_notification.manage',
            'name' => 'Manage Telegram notification settings and routes',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'translation.approve_deploy',
            'name' => 'Preview, approve, or reject translation deploy requests',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'reward_entry.resolve',
            'name' => 'Resolve reward entry submissions into final reward results',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'storage_connection.manage',
            'name' => 'Manage platform object storage connection settings',
            'status' => 'active',
        ]);
    }

    public function test_default_menus_seed_with_documented_permission_codes(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertSame(36, DB::table('admin_menus')->where('scope_type', 'central')->count());
        $this->assertSame(38, DB::table('admin_menus')->where('scope_type', 'tenant')->count());

        $dashboardParentId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard')
            ->value('id');

        $this->assertNotSame('', $dashboardParentId);
        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'dashboard',
            'label' => 'Dashboard',
            'route' => '/admin/central/dashboard',
            'category' => 'Dashboard',
            'required_permission_code' => 'dashboard.view',
            'status' => 'active',
        ]);

        foreach ([
            'dashboard_sales' => '/admin/central/dashboard/sales',
            'dashboard_partner' => '/admin/central/dashboard/partner',
            'dashboard_wallet' => '/admin/central/dashboard/wallet',
            'dashboard_payout' => '/admin/central/dashboard/payout',
            'dashboard_monitor' => '/admin/central/dashboard/monitor',
        ] as $code => $route) {
            $this->assertDatabaseHas('admin_menus', [
                'scope_type' => 'central',
                'code' => $code,
                'parent_id' => $dashboardParentId,
                'route' => $route,
                'category' => 'Dashboard',
                'required_permission_code' => 'dashboard.view',
                'status' => 'active',
            ]);
        }

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'storage_connections',
            'label' => 'Storage Connections',
            'route' => '/admin/central/storage-connections',
            'category' => 'Administration',
            'required_permission_code' => 'storage_connection.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partner_monitoring',
            'required_permission_code' => 'partner.monitoring.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'support_access_logs',
            'required_permission_code' => 'support_access.audit',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_generation',
            'label' => 'Stock Manager',
            'route' => '/admin/central/stock',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'sale_price_rules',
            'label' => 'Sale Price Rules',
            'route' => '/admin/central/sale-price-rules',
            'required_permission_code' => 'price_rule.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'reward_payout_rules',
            'label' => 'Reward Payout Rules',
            'route' => '/admin/central/reward-payout-rules',
            'required_permission_code' => 'price_rule.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'winners',
            'label' => 'Winners',
            'route' => '/admin/central/winners',
            'category' => 'Lottery Operations',
            'required_permission_code' => 'reward.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'reward_entry',
            'label' => 'Result Entry',
            'route' => '/admin/central/reward-entry',
            'category' => 'Lottery Operations',
            'required_permission_code' => 'reward_entry.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'lottery_images',
            'label' => 'Lottery Images',
            'route' => '/admin/central/lottery-images',
            'category' => 'Lottery Operations',
            'required_permission_code' => 'asset.manage',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'winners',
            'label' => 'Winners',
            'route' => '/admin/tenant/winners',
            'category' => 'Store Operations',
            'required_permission_code' => 'reward_claim.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'exchange_reward',
            'label' => 'Exchange Reward',
            'route' => '/admin/tenant/exchange-reward',
            'category' => 'Store Operations',
            'required_permission_code' => 'reward_claim.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'announcements',
            'label' => 'Announcements',
            'route' => '/admin/tenant/announcements',
            'category' => 'Store Operations',
            'required_permission_code' => 'announcement.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'activities',
            'label' => 'Activities',
            'route' => '/admin/tenant/activities',
            'category' => 'Store Operations',
            'required_permission_code' => 'activity.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'activity_claims',
            'label' => 'Activity Claims',
            'route' => '/admin/tenant/activity-claims',
            'category' => 'Store Operations',
            'required_permission_code' => 'activity.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'line_notifications',
            'label' => 'LINE Notifications',
            'route' => '/admin/tenant/line-notifications',
            'category' => 'Store Operations',
            'required_permission_code' => 'line_notification.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'master_stock',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_recall',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partners',
            'label' => 'Partner/Tenant',
            'route' => '/admin/central/partners',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'maintenance',
            'label' => 'Central Maintenance',
            'route' => '/admin/central/maintenance',
            'category' => 'Partner Operations',
            'required_permission_code' => 'partner.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'telegram_notifications',
            'label' => 'Telegram Notifications',
            'route' => '/admin/central/telegram-notifications',
            'category' => 'Administration',
            'required_permission_code' => 'telegram_notification.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'translations',
            'label' => 'Translation Center',
            'route' => '/admin/central/translations',
            'category' => 'Administration',
            'required_permission_code' => 'translation.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partner_provisioning',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'local_stock',
            'label' => 'Tenant Stock',
            'route' => '/admin/tenant/stock',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'stock_sync',
        ]);
    }

    public function test_reseeding_does_not_duplicate_permissions_or_menus(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);
        $this->seed(DefaultRbacMenuSeeder::class);

        $seeder = new DefaultRbacMenuSeeder;

        $this->assertSame(count($seeder->permissions()), DB::table('permissions')->count());
        $this->assertSame(count($seeder->menus()), DB::table('admin_menus')->count());

        $this->assertSame(1, DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard.view')
            ->count());

        $this->assertSame(1, DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'dashboard.view')
            ->count());

        $dashboardParentId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard')
            ->value('id');

        $this->assertNotSame('', $dashboardParentId);

        $this->assertSame(5, DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->whereIn('code', ['dashboard_sales', 'dashboard_partner', 'dashboard_wallet', 'dashboard_payout', 'dashboard_monitor'])
            ->where('parent_id', $dashboardParentId)
            ->count());

        $this->assertSame(1, DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'dashboard')
            ->count());
    }

    public function test_reseeding_removes_retired_stock_recall_menu(): void
    {
        DB::table('admin_menus')->insert([
            'id' => 'men_retired_stock_recall',
            'scope_type' => 'central',
            'parent_id' => null,
            'code' => 'stock_recall',
            'label' => 'Stock Recall',
            'route' => '/admin/central/stock',
            'required_permission_code' => 'stock.recall',
            'sort_order' => 999,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_recall',
        ]);
    }

    public function test_reseeding_grants_lottery_operation_permissions_to_central_super_admin_role(): void
    {
        DB::table('roles')->insert([
            'id' => 'rol_c_super_admin',
            'scope_type' => 'central',
            'tenant_id' => null,
            'code' => 'super_admin',
            'name' => 'Platform Super Admin',
            'status' => 'active',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $permissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['price_rule.view', 'price_rule.manage'])
            ->pluck('id')
            ->all();
        $priceRuleMenuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->whereIn('code', ['sale_price_rules', 'reward_payout_rules'])
            ->pluck('id')
            ->all();
        $partnerPermissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['partner.view', 'partner.update'])
            ->pluck('id')
            ->all();
        $centralMaintenanceMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'maintenance')
            ->value('id');
        $dashboardMenuIds = DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->whereIn('code', ['dashboard', 'dashboard_sales', 'dashboard_partner', 'dashboard_wallet', 'dashboard_payout', 'dashboard_monitor'])
            ->pluck('id')
            ->all();
        $translationPermissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['translation.view', 'translation.edit', 'translation.request_deploy', 'translation.approve_deploy'])
            ->pluck('id')
            ->all();
        $translationApprovePermissionId = (string) DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'translation.approve_deploy')
            ->value('id');
        $translationMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'translations')
            ->value('id');
        $rewardEntryPermissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['reward_entry.view', 'reward_entry.submit', 'reward_entry.resolve'])
            ->pluck('id')
            ->all();
        $rewardEntryMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'reward_entry')
            ->value('id');

        $this->assertSame(2, DB::table('role_permissions')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('permission_id', $permissionIds)
            ->count());
        $this->assertSame(6, DB::table('role_menus')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('menu_id', $dashboardMenuIds)
            ->count());
        $this->assertSame(2, DB::table('role_menus')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('menu_id', $priceRuleMenuIds)
            ->count());
        $this->assertSame(2, DB::table('role_permissions')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('permission_id', $partnerPermissionIds)
            ->count());
        $this->assertDatabaseHas('role_menus', [
            'role_id' => 'rol_c_super_admin',
            'menu_id' => $centralMaintenanceMenuId,
        ]);

        $rewardPermissionId = (string) DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'reward.view')
            ->value('id');
        $winnerMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'winners')
            ->value('id');

        $this->assertDatabaseHas('role_permissions', [
            'role_id' => 'rol_c_super_admin',
            'permission_id' => $rewardPermissionId,
        ]);
        $this->assertDatabaseHas('role_menus', [
            'role_id' => 'rol_c_super_admin',
            'menu_id' => $winnerMenuId,
        ]);

        $this->assertSame(4, DB::table('role_permissions')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('permission_id', $translationPermissionIds)
            ->count());
        $this->assertDatabaseHas('role_menus', [
            'role_id' => 'rol_c_super_admin',
            'menu_id' => $translationMenuId,
        ]);
        $this->assertSame(3, DB::table('role_permissions')
            ->where('role_id', 'rol_c_super_admin')
            ->whereIn('permission_id', $rewardEntryPermissionIds)
            ->count());
        $this->assertDatabaseHas('role_menus', [
            'role_id' => 'rol_c_super_admin',
            'menu_id' => $rewardEntryMenuId,
        ]);

        $translatorPermissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['translation.view', 'translation.edit', 'translation.request_deploy'])
            ->pluck('id')
            ->all();
        $this->assertDatabaseHas('roles', [
            'id' => 'rol_c_translator',
            'scope_type' => 'central',
            'tenant_id' => null,
            'code' => 'translator',
            'status' => 'active',
        ]);
        $this->assertSame(3, DB::table('role_permissions')
            ->where('role_id', 'rol_c_translator')
            ->whereIn('permission_id', $translatorPermissionIds)
            ->count());
        $this->assertSame(0, DB::table('role_permissions')
            ->where('role_id', 'rol_c_translator')
            ->where('permission_id', $translationApprovePermissionId)
            ->count());
        $this->assertSame(1, DB::table('role_menus')
            ->where('role_id', 'rol_c_translator')
            ->where('menu_id', $translationMenuId)
            ->count());

        $resultOfficerPermissionIds = DB::table('permissions')
            ->where('scope_type', 'central')
            ->whereIn('code', ['reward_entry.view', 'reward_entry.submit'])
            ->pluck('id')
            ->all();
        $rewardEntryResolvePermissionId = (string) DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'reward_entry.resolve')
            ->value('id');
        $this->assertDatabaseHas('roles', [
            'id' => 'rol_c_result_officer',
            'scope_type' => 'central',
            'tenant_id' => null,
            'code' => 'result_officer',
            'status' => 'active',
        ]);
        $this->assertSame(2, DB::table('role_permissions')
            ->where('role_id', 'rol_c_result_officer')
            ->whereIn('permission_id', $resultOfficerPermissionIds)
            ->count());
        $this->assertSame(0, DB::table('role_permissions')
            ->where('role_id', 'rol_c_result_officer')
            ->where('permission_id', $rewardEntryResolvePermissionId)
            ->count());
        $this->assertSame(1, DB::table('role_menus')
            ->where('role_id', 'rol_c_result_officer')
            ->where('menu_id', $rewardEntryMenuId)
            ->count());
        $this->assertSame(0, DB::table('role_menus')
            ->where('role_id', 'rol_c_result_officer')
            ->where('menu_id', $winnerMenuId)
            ->count());
    }

    public function test_reseeding_grants_tenant_winners_maintenance_and_announcements_to_partner_owner_roles(): void
    {
        DB::table('partners')->insert([
            [
                'id' => 'par_rbac_owner',
                'code' => 'par_rbac_owner',
                'name' => 'RBAC Owner Partner',
                'type' => 'partner_store',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'par_rbac_owner_partner',
                'code' => 'par_rbac_owner_partner',
                'name' => 'RBAC Owner Partner Role Partner',
                'type' => 'partner_store',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        DB::table('partner_tenants')->insert([
            [
                'id' => 'ten_rbac_owner',
                'partner_id' => 'par_rbac_owner',
                'code' => 'ten_rbac_owner',
                'name' => 'RBAC Owner Tenant',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'ten_rbac_owner_partner',
                'partner_id' => 'par_rbac_owner_partner',
                'code' => 'ten_rbac_owner_partner',
                'name' => 'RBAC Owner Partner Tenant',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        DB::table('roles')->insert([
            [
                'id' => 'rol_t_owner',
                'scope_type' => 'tenant',
                'tenant_id' => 'ten_rbac_owner',
                'code' => 'owner',
                'name' => 'Tenant Owner',
                'status' => 'active',
                'version' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'rol_t_owner_partner',
                'scope_type' => 'tenant',
                'tenant_id' => 'ten_rbac_owner_partner',
                'code' => 'owner_partner',
                'name' => 'Owner Partner',
                'status' => 'active',
                'version' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $rewardClaimPermissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['reward_claim.view', 'reward_claim.approve', 'reward_claim.reject'])
            ->pluck('id')
            ->all();
        $rewardClaimMenuIds = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['winners', 'exchange_reward'])
            ->pluck('id')
            ->all();
        $maintenancePermissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['maintenance.view', 'maintenance.update', 'maintenance.schedule', 'maintenance.bypass'])
            ->pluck('id')
            ->all();
        $maintenanceMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'maintenance')
            ->value('id');
        $announcementPermissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['announcement.view', 'announcement.manage'])
            ->pluck('id')
            ->all();
        $announcementMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'announcements')
            ->value('id');
        $activityPermissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['activity.view', 'activity.manage'])
            ->pluck('id')
            ->all();
        $activityMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'activities')
            ->value('id');
        $linePermissionIds = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['line_notification.view', 'line_notification.manage'])
            ->pluck('id')
            ->all();
        $lineMenuId = (string) DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'line_notifications')
            ->value('id');

        foreach (['rol_t_owner', 'rol_t_owner_partner'] as $roleId) {
            foreach ($rewardClaimPermissionIds as $permissionId) {
                $this->assertDatabaseHas('role_permissions', [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
            foreach ($rewardClaimMenuIds as $menuId) {
                $this->assertDatabaseHas('role_menus', [
                    'role_id' => $roleId,
                    'menu_id' => $menuId,
                ]);
            }
            foreach ($maintenancePermissionIds as $permissionId) {
                $this->assertDatabaseHas('role_permissions', [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
            $this->assertDatabaseHas('role_menus', [
                'role_id' => $roleId,
                'menu_id' => $maintenanceMenuId,
            ]);
            foreach ($announcementPermissionIds as $permissionId) {
                $this->assertDatabaseHas('role_permissions', [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
            $this->assertDatabaseHas('role_menus', [
                'role_id' => $roleId,
                'menu_id' => $announcementMenuId,
            ]);
            foreach ($activityPermissionIds as $permissionId) {
                $this->assertDatabaseHas('role_permissions', [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
            $this->assertDatabaseHas('role_menus', [
                'role_id' => $roleId,
                'menu_id' => $activityMenuId,
            ]);
            foreach ($linePermissionIds as $permissionId) {
                $this->assertDatabaseHas('role_permissions', [
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
            $this->assertDatabaseHas('role_menus', [
                'role_id' => $roleId,
                'menu_id' => $lineMenuId,
            ]);
        }
    }

    public function test_reseeding_removes_retired_tenant_stock_sync_menu_and_permission(): void
    {
        DB::table('permissions')->insert([
            'id' => 'per_retired_stock_sync',
            'scope_type' => 'tenant',
            'code' => 'stock.sync',
            'name' => 'Run or view stock sync',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_menus')->insert([
            'id' => 'men_retired_stock_sync',
            'scope_type' => 'tenant',
            'parent_id' => null,
            'code' => 'stock_sync',
            'label' => 'Stock Sync',
            'route' => '/admin/tenant/stock-sync',
            'required_permission_code' => 'stock.sync',
            'sort_order' => 999,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'stock_sync',
        ]);
        $this->assertDatabaseMissing('permissions', [
            'scope_type' => 'tenant',
            'code' => 'stock.sync',
        ]);
    }
}
