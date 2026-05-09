<?php

namespace Database\Seeders;

use App\Models\AdminMenu;
use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminScope;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\Permission;
use App\Models\Role;
use App\Models\RoleMenu;
use App\Models\RolePermission;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class BootstrapAdminSeeder extends Seeder
{
    private const CENTRAL_SCOPE_ID = 'scp_c_platform';
    private const CENTRAL_ROLE_ID = 'rol_c_super_admin';
    private const CENTRAL_ADMIN_ID = 'adm_platform_owner';

    public function run(): void
    {
        $now = now();

        AdminScope::updateOrCreate(
            ['id' => self::CENTRAL_SCOPE_ID],
            [
                'scope_type' => 'central',
                'tenant_id' => null,
                'partner_id' => null,
            ],
        );

        Role::updateOrCreate(
            ['id' => self::CENTRAL_ROLE_ID],
            [
                'scope_type' => 'central',
                'tenant_id' => null,
                'code' => 'super_admin',
                'name' => 'Platform Super Admin',
                'status' => 'active',
                'version' => 1,
            ],
        );

        AdminUser::updateOrCreate(
            ['email' => $this->centralAdminEmail()],
            [
                'id' => self::CENTRAL_ADMIN_ID,
                'name' => 'Platform Owner',
                'phone' => null,
                'password_hash' => Hash::make($this->centralAdminPassword()),
                'status' => 'active',
                'two_factor_enabled' => false,
            ],
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => self::CENTRAL_ADMIN_ID,
            'role_id' => self::CENTRAL_ROLE_ID,
            'scope_id' => self::CENTRAL_SCOPE_ID,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        $this->syncRolePermissions(self::CENTRAL_ROLE_ID, 'central', $now);
        $this->syncRoleMenus(self::CENTRAL_ROLE_ID, 'central', $now);

        AdminPermissionCacheVersion::updateOrCreate(
            ['admin_user_id' => self::CENTRAL_ADMIN_ID, 'scope_id' => self::CENTRAL_SCOPE_ID],
            [
                'id' => $this->stableId('pcv', self::CENTRAL_ADMIN_ID.':'.self::CENTRAL_SCOPE_ID),
                'version' => 2,
            ],
        );
    }

    private function centralAdminEmail(): string
    {
        return strtolower(trim((string) config('platform.seed.central_admin_email')));
    }

    private function centralAdminPassword(): string
    {
        return (string) config('platform.seed.central_admin_password');
    }

    private function syncRolePermissions(string $roleId, string $scopeType, mixed $now): void
    {
        $permissionIds = Permission::where('scope_type', $scopeType)
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        RolePermission::query()->insertOrIgnore(array_map(fn (string $permissionId): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
            'created_at' => $now,
            'updated_at' => $now,
        ], $permissionIds));
    }

    private function syncRoleMenus(string $roleId, string $scopeType, mixed $now): void
    {
        $menuIds = AdminMenu::where('scope_type', $scopeType)
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        RoleMenu::query()->insertOrIgnore(array_map(fn (string $menuId): array => [
            'role_id' => $roleId,
            'menu_id' => $menuId,
            'created_at' => $now,
            'updated_at' => $now,
        ], $menuIds));
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
}
