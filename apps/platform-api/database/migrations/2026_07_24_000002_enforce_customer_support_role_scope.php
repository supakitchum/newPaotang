<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (
            ! Schema::hasTable('roles')
            || ! Schema::hasTable('permissions')
            || ! Schema::hasTable('admin_menus')
            || ! Schema::hasTable('role_permissions')
            || ! Schema::hasTable('role_menus')
        ) {
            return;
        }

        $permissionIds = DB::table('permissions')
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
        $supportMenuId = DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_support')
            ->value('id');
        $definitions = [
            'support' => [
                'support_ticket.view_assigned',
                'support_ticket.reply_assigned',
                'support_ticket.close_assigned',
            ],
            'master_support' => array_keys($permissionIds->all()),
        ];
        $roleIds = [];

        foreach ($definitions as $roleCode => $permissionCodes) {
            $roles = DB::table('roles')
                ->where('scope_type', 'tenant')
                ->where('code', $roleCode)
                ->get(['id']);
            $allowedPermissionIds = collect($permissionCodes)
                ->map(fn (string $permissionCode): ?string => $permissionIds[$permissionCode] ?? null)
                ->filter()
                ->values()
                ->all();

            foreach ($roles as $role) {
                $roleId = (string) $role->id;
                $roleIds[] = $roleId;
                $permissionQuery = DB::table('role_permissions')->where('role_id', $roleId);
                $allowedPermissionIds === []
                    ? $permissionQuery->delete()
                    : $permissionQuery->whereNotIn('permission_id', $allowedPermissionIds)->delete();

                foreach ($allowedPermissionIds as $permissionId) {
                    DB::table('role_permissions')->insertOrIgnore([
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                $menuQuery = DB::table('role_menus')->where('role_id', $roleId);
                if ($supportMenuId === null) {
                    $menuQuery->delete();
                } else {
                    $menuQuery->where('menu_id', '!=', $supportMenuId)->delete();
                    DB::table('role_menus')->insertOrIgnore([
                        'role_id' => $roleId,
                        'menu_id' => $supportMenuId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        $roleIds = array_values(array_unique($roleIds));
        if ($roleIds === []) {
            return;
        }

        DB::table('roles')
            ->whereIn('id', $roleIds)
            ->update([
                'version' => DB::raw('version + 1'),
                'updated_at' => now(),
            ]);
        $this->bumpPermissionCacheVersions($roleIds);
    }

    public function down(): void
    {
        // Removed grants are intentionally not restored because their original source is unknown.
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function bumpPermissionCacheVersions(array $roleIds): void
    {
        if (! Schema::hasTable('admin_user_roles') || ! Schema::hasTable('admin_permission_cache_versions')) {
            return;
        }

        $now = now();
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
                            'id' => 'pcv_'.substr(sha1($keys['admin_user_id'].':'.$keys['scope_id']), 0, 20),
                            ...$keys,
                            'version' => 2,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                    }
                }
            });
    }
};
