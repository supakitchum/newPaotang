<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('permissions') || ! Schema::hasTable('admin_menus')) {
            return;
        }

        $now = now();
        $permissions = [
            'affiliate_name_review.view' => 'View affiliate store name review requests',
            'affiliate_name_review.manage' => 'Approve or reject affiliate store names',
            'affiliate_tier.view' => 'View affiliate tiers',
            'affiliate_tier.manage' => 'Manage affiliate tier benefits',
            'affiliate_tier_campaign.view' => 'View affiliate tier campaigns',
            'affiliate_tier_campaign.manage' => 'Manage and finalize affiliate tier campaigns',
        ];
        foreach ($permissions as $code => $name) {
            DB::table('permissions')->updateOrInsert(
                ['scope_type' => 'tenant', 'code' => $code],
                [
                    'id' => DB::table('permissions')->where('scope_type', 'tenant')->where('code', $code)->value('id')
                        ?? $this->stableId('per', 'tenant:'.$code),
                    'name' => $name,
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        $parentId = DB::table('admin_menus')->where('scope_type', 'tenant')->where('code', 'affiliate')->value('id');
        $menus = [
            'affiliate_store_name_requests' => [
                'label' => 'Affiliate Store Name Reviews',
                'route' => '/admin/tenant/growth/affiliate-store-name-requests',
                'permission' => 'affiliate_name_review.view',
                'sort' => 315,
            ],
            'affiliate_tiers' => [
                'label' => 'Affiliate Tiers',
                'route' => '/admin/tenant/growth/affiliate-tiers',
                'permission' => 'affiliate_tier.view',
                'sort' => 320,
            ],
            'affiliate_tier_campaigns' => [
                'label' => 'Affiliate Tier Campaigns',
                'route' => '/admin/tenant/growth/affiliate-tier-campaigns',
                'permission' => 'affiliate_tier_campaign.view',
                'sort' => 325,
            ],
        ];
        $menuIds = [];
        foreach ($menus as $code => $menu) {
            $menuId = DB::table('admin_menus')->where('scope_type', 'tenant')->where('code', $code)->value('id')
                ?? $this->stableId('men', 'tenant:'.$code);
            $menuIds[] = (string) $menuId;
            DB::table('admin_menus')->updateOrInsert(
                ['scope_type' => 'tenant', 'code' => $code],
                [
                    'id' => $menuId,
                    'parent_id' => $parentId,
                    'label' => $menu['label'],
                    'route' => $menu['route'],
                    'category' => 'Tenant Growth',
                    'icon' => 'ri-vip-crown-2-line',
                    'required_permission_code' => $menu['permission'],
                    'sort_order' => $menu['sort'],
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        if (! Schema::hasTable('roles')) {
            return;
        }
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner', 'owner_partner'])
            ->where('status', 'active')
            ->pluck('id')
            ->map(fn (mixed $id): string => (string) $id)
            ->all();
        if (Schema::hasTable('role_permissions')) {
            $permissionIds = DB::table('permissions')
                ->where('scope_type', 'tenant')
                ->whereIn('code', array_keys($permissions))
                ->pluck('id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();
            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $rows[] = ['role_id' => $roleId, 'permission_id' => $permissionId, 'created_at' => $now, 'updated_at' => $now];
                }
            }
            DB::table('role_permissions')->insertOrIgnore($rows);
        }
        if (Schema::hasTable('role_menus')) {
            $rows = [];
            foreach ($roleIds as $roleId) {
                foreach ($menuIds as $menuId) {
                    $rows[] = ['role_id' => $roleId, 'menu_id' => $menuId, 'created_at' => $now, 'updated_at' => $now];
                }
            }
            DB::table('role_menus')->insertOrIgnore($rows);
        }
    }

    public function down(): void
    {
        // Keep production grants intact when rolling schema back.
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
};
