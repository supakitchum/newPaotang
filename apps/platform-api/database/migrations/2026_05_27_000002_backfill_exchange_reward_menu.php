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
        $permissionNames = [
            'reward_claim.view' => 'View reward exchange requests',
            'reward_claim.approve' => 'Approve reward exchange requests',
            'reward_claim.reject' => 'Reject reward exchange requests',
        ];

        foreach ($permissionNames as $code => $name) {
            $existingId = DB::table('permissions')
                ->where('scope_type', 'tenant')
                ->where('code', $code)
                ->value('id');

            if ($existingId === null) {
                DB::table('permissions')->insert([
                    'id' => $this->stableId('per', 'tenant:'.$code),
                    'scope_type' => 'tenant',
                    'code' => $code,
                    'name' => $name,
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                continue;
            }

            DB::table('permissions')
                ->where('id', $existingId)
                ->update([
                    'name' => $name,
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        }

        $menuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'exchange_reward')
            ->value('id');
        $menuPayload = [
            'parent_id' => null,
            'label' => 'Exchange Reward',
            'route' => '/admin/tenant/exchange-reward',
            'category' => 'Store Operations',
            'icon' => 'ri-exchange-dollar-line',
            'required_permission_code' => 'reward_claim.view',
            'sort_order' => 115,
            'status' => 'active',
            'updated_at' => $now,
        ];

        if ($menuId === null) {
            $menuId = $this->stableId('men', 'tenant:exchange_reward');
            DB::table('admin_menus')->insert([
                'id' => $menuId,
                'scope_type' => 'tenant',
                'code' => 'exchange_reward',
                'created_at' => $now,
                ...$menuPayload,
            ]);
        } else {
            DB::table('admin_menus')
                ->where('id', $menuId)
                ->update($menuPayload);
        }

        if (! Schema::hasTable('roles')) {
            return;
        }

        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner', 'owner_partner'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($roleIds === []) {
            return;
        }

        if (Schema::hasTable('role_permissions')) {
            $permissionIds = DB::table('permissions')
                ->where('scope_type', 'tenant')
                ->whereIn('code', array_keys($permissionNames))
                ->where('status', 'active')
                ->pluck('id')
                ->all();

            $permissionRows = [];
            foreach ($roleIds as $roleId) {
                foreach ($permissionIds as $permissionId) {
                    $permissionRows[] = [
                        'role_id' => (string) $roleId,
                        'permission_id' => (string) $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }
            DB::table('role_permissions')->insertOrIgnore($permissionRows);
        }

        if (Schema::hasTable('role_menus')) {
            $menuRows = array_map(fn (string $roleId): array => [
                'role_id' => $roleId,
                'menu_id' => (string) $menuId,
                'created_at' => $now,
                'updated_at' => $now,
            ], $roleIds);
            DB::table('role_menus')->insertOrIgnore($menuRows);
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    public function down(): void
    {
        // Keep the menu and grants because this migration is a production backfill.
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function bumpPermissionCacheVersions(array $roleIds, mixed $now): void
    {
        if ($roleIds === [] || ! Schema::hasTable('admin_user_roles') || ! Schema::hasTable('admin_permission_cache_versions')) {
            return;
        }

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
                        'id' => $this->stableId('pcv', $keys['admin_user_id'].':'.$keys['scope_id']),
                        ...$keys,
                        'version' => 2,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
            });
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
};
