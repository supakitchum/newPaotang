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
        $roleIds = [];

        foreach ([
            'central' => [
                'roles' => ['super_admin'],
                'route' => '/admin/central/reward-risk',
                'category' => 'Lottery Operations',
            ],
            'tenant' => [
                'roles' => ['owner', 'owner_partner'],
                'route' => '/admin/tenant/reward-risk',
                'category' => 'Store Operations',
            ],
        ] as $scopeType => $config) {
            $permissionIds = [];
            foreach ([
                'reward_risk.view' => 'View reward risk assessments',
                'reward_risk.manage' => 'Manage reward risk assessment settings',
            ] as $code => $name) {
                $permissionId = DB::table('permissions')
                    ->where('scope_type', $scopeType)
                    ->where('code', $code)
                    ->value('id');
                $payload = ['name' => $name, 'status' => 'active', 'updated_at' => $now];
                if ($permissionId === null) {
                    $permissionId = $this->stableId('per', $scopeType.':'.$code);
                    DB::table('permissions')->insert([
                        'id' => $permissionId,
                        'scope_type' => $scopeType,
                        'code' => $code,
                        'created_at' => $now,
                        ...$payload,
                    ]);
                } else {
                    DB::table('permissions')->where('id', $permissionId)->update($payload);
                }
                $permissionIds[] = (string) $permissionId;
            }

            $menuId = DB::table('admin_menus')
                ->where('scope_type', $scopeType)
                ->where('code', 'reward_risk')
                ->value('id');
            $menuPayload = [
                'parent_id' => null,
                'label' => 'Reward Risk Assessment',
                'route' => $config['route'],
                'category' => $config['category'],
                'icon' => 'ri-radar-line',
                'required_permission_code' => 'reward_risk.view',
                'sort_order' => 125,
                'status' => 'active',
                'updated_at' => $now,
            ];
            if ($menuId === null) {
                $menuId = $this->stableId('men', $scopeType.':reward_risk');
                DB::table('admin_menus')->insert([
                    'id' => $menuId,
                    'scope_type' => $scopeType,
                    'code' => 'reward_risk',
                    'created_at' => $now,
                    ...$menuPayload,
                ]);
            } else {
                DB::table('admin_menus')->where('id', $menuId)->update($menuPayload);
            }

            if (! Schema::hasTable('roles')) {
                continue;
            }
            $roles = DB::table('roles')
                ->where('scope_type', $scopeType)
                ->whereIn('code', $config['roles'])
                ->where('status', 'active')
                ->pluck('id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();
            $roleIds = [...$roleIds, ...$roles];

            if (Schema::hasTable('role_permissions')) {
                $rows = [];
                foreach ($roles as $roleId) {
                    foreach ($permissionIds as $permissionId) {
                        $rows[] = [
                            'role_id' => $roleId,
                            'permission_id' => $permissionId,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }
                }
                if ($rows !== []) {
                    DB::table('role_permissions')->insertOrIgnore($rows);
                }
            }

            if (Schema::hasTable('role_menus') && $roles !== []) {
                DB::table('role_menus')->insertOrIgnore(array_map(fn (string $roleId): array => [
                    'role_id' => $roleId,
                    'menu_id' => (string) $menuId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $roles));
            }
        }

        $this->bumpPermissionCacheVersions(array_values(array_unique($roleIds)), $now);
    }

    public function down(): void
    {
        // Keep the assessment menu and grants when rolling back schema changes.
    }

    private function bumpPermissionCacheVersions(array $roleIds, mixed $now): void
    {
        if ($roleIds === [] || ! Schema::hasTable('admin_user_roles') || ! Schema::hasTable('admin_permission_cache_versions')) {
            return;
        }

        DB::table('admin_user_roles')
            ->whereIn('role_id', $roleIds)
            ->select(['admin_user_id', 'scope_id'])
            ->distinct()
            ->orderBy('admin_user_id')
            ->chunk(100, function ($rows) use ($now): void {
                foreach ($rows as $row) {
                    $keys = [
                        'admin_user_id' => (string) $row->admin_user_id,
                        'scope_id' => (string) $row->scope_id,
                    ];
                    $updated = DB::table('admin_permission_cache_versions')->where($keys)->update([
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
