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
            'customer_notification.view' => 'View customer notification history',
            'customer_notification.send' => 'Send notifications to tenant customers',
        ];

        foreach ($permissionNames as $code => $name) {
            $permissionId = DB::table('permissions')
                ->where('scope_type', 'tenant')
                ->where('code', $code)
                ->value('id');
            $payload = [
                'name' => $name,
                'status' => 'active',
                'updated_at' => $now,
            ];

            if ($permissionId === null) {
                DB::table('permissions')->insert([
                    'id' => $this->stableId('per', 'tenant:'.$code),
                    'scope_type' => 'tenant',
                    'code' => $code,
                    'created_at' => $now,
                    ...$payload,
                ]);
            } else {
                DB::table('permissions')->where('id', $permissionId)->update($payload);
            }
        }

        $menuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_notifications')
            ->value('id');
        $menuPayload = [
            'parent_id' => null,
            'label' => 'Customer Notifications',
            'route' => '/admin/tenant/customer-notifications',
            'category' => 'Store Operations',
            'icon' => 'ri-notification-3-line',
            'required_permission_code' => 'customer_notification.view',
            'sort_order' => 230,
            'status' => 'active',
            'updated_at' => $now,
        ];

        if ($menuId === null) {
            $menuId = $this->stableId('men', 'tenant:customer_notifications');
            DB::table('admin_menus')->insert([
                'id' => $menuId,
                'scope_type' => 'tenant',
                'code' => 'customer_notifications',
                'created_at' => $now,
                ...$menuPayload,
            ]);
        } else {
            DB::table('admin_menus')->where('id', $menuId)->update($menuPayload);
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

        if ($roleIds === []) {
            return;
        }

        if (Schema::hasTable('role_permissions')) {
            $permissionIds = DB::table('permissions')
                ->where('scope_type', 'tenant')
                ->whereIn('code', array_keys($permissionNames))
                ->where('status', 'active')
                ->pluck('id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();
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

        if (Schema::hasTable('role_menus')) {
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
        // Keep the production menu and grants when rolling back schema changes.
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function bumpPermissionCacheVersions(array $roleIds, mixed $now): void
    {
        if (! Schema::hasTable('admin_user_roles') || ! Schema::hasTable('admin_permission_cache_versions')) {
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

                    if ($updated === 0) {
                        DB::table('admin_permission_cache_versions')->insert([
                            'id' => $this->stableId('pcv', $keys['admin_user_id'].':'.$keys['scope_id']),
                            ...$keys,
                            'version' => 2,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                    }
                }
            });
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
};
