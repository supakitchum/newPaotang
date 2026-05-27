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

        $existingPermissionId = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'reward_claim.view')
            ->value('id');

        if ($existingPermissionId === null) {
            DB::table('permissions')->insert([
                'id' => $this->stableId('per', 'tenant:reward_claim.view'),
                'scope_type' => 'tenant',
                'code' => 'reward_claim.view',
                'name' => 'View reward cashout claims',
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            DB::table('permissions')
                ->where('id', $existingPermissionId)
                ->update([
                    'name' => 'View reward cashout claims',
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        }

        $existingMenuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'winners')
            ->value('id');

        if ($existingMenuId === null) {
            DB::table('admin_menus')->insert([
                'id' => $this->stableId('men', 'tenant:winners'),
                'scope_type' => 'tenant',
                'code' => 'winners',
                'parent_id' => null,
                'label' => 'Winners',
                'route' => '/admin/tenant/winners',
                'category' => 'Store Operations',
                'icon' => 'ri-trophy-line',
                'required_permission_code' => 'reward_claim.view',
                'sort_order' => 110,
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            DB::table('admin_menus')
                ->where('id', $existingMenuId)
                ->update([
                    'parent_id' => null,
                    'label' => 'Winners',
                    'route' => '/admin/tenant/winners',
                    'category' => 'Store Operations',
                    'icon' => 'ri-trophy-line',
                    'required_permission_code' => 'reward_claim.view',
                    'sort_order' => 110,
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
        }

        if (! Schema::hasTable('roles')) {
            return;
        }

        $permissionId = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'reward_claim.view')
            ->value('id');
        $menuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'winners')
            ->value('id');
        $roleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->whereIn('code', ['owner', 'owner_partner'])
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($roleIds !== [] && $permissionId !== null && Schema::hasTable('role_permissions')) {
            DB::table('role_permissions')->insertOrIgnore(array_map(fn (string $roleId): array => [
                'role_id' => $roleId,
                'permission_id' => (string) $permissionId,
                'created_at' => $now,
                'updated_at' => $now,
            ], $roleIds));
        }

        if ($roleIds !== [] && $menuId !== null && Schema::hasTable('role_menus')) {
            DB::table('role_menus')->insertOrIgnore(array_map(fn (string $roleId): array => [
                'role_id' => $roleId,
                'menu_id' => (string) $menuId,
                'created_at' => $now,
                'updated_at' => $now,
            ], $roleIds));
        }

        $this->bumpPermissionCacheVersions($roleIds, $now);
    }

    public function down(): void
    {
        // Keep the backfilled menu and owner grants on rollback.
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
