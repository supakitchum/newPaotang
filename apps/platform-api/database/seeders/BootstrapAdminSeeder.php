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
    private const CENTRAL_USERNAME = 'superadmin';
    private const TRANSLATOR_ROLE_ID = 'rol_c_translator';
    private const TRANSLATOR_ADMIN_ID = 'adm_translator';
    private const TRANSLATOR_USERNAME = 'translator';
    private const RESULT_OFFICER_ROLE_ID = 'rol_c_result_officer';
    private const RESULT_OFFICER_ADMIN_ID = 'adm_result_officer';
    private const RESULT_OFFICER_USERNAME = 'result';
    private const LOTTERY_UPLOADER_ROLE_ID = 'rol_c_lottery_uploader';
    private const LOTTERY_UPLOADER_ADMIN_ID = 'adm_lottery_uploader';
    private const LOTTERY_UPLOADER_USERNAME = 'uploader';

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

        $this->retireLegacyAdminUsernames();

        AdminUser::updateOrCreate(
            ['id' => self::CENTRAL_ADMIN_ID],
            [
                'email' => self::CENTRAL_USERNAME.'@newpaotang.test',
                'username' => self::CENTRAL_USERNAME,
                'name' => 'Platform Owner',
                'phone' => null,
                'password_hash' => Hash::make('1234'),
                'status' => 'active',
                'preferred_locale' => 'th-TH',
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

        $this->seedTranslatorAdmin($now);
        $this->seedResultOfficerAdmin($now);
        $this->seedLotteryUploaderAdmin($now);

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

    private function seedTranslatorAdmin(mixed $now): void
    {
        if (! Role::query()->where('id', self::TRANSLATOR_ROLE_ID)->exists()) {
            return;
        }

        AdminUser::updateOrCreate(
            ['id' => self::TRANSLATOR_ADMIN_ID],
            [
                'email' => self::TRANSLATOR_USERNAME.'@newpaotang.test',
                'username' => self::TRANSLATOR_USERNAME,
                'name' => 'Translator Master',
                'phone' => null,
                'password_hash' => Hash::make('1234'),
                'status' => 'active',
                'preferred_locale' => 'th-TH',
                'two_factor_enabled' => false,
            ],
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => self::TRANSLATOR_ADMIN_ID,
            'role_id' => self::TRANSLATOR_ROLE_ID,
            'scope_id' => self::CENTRAL_SCOPE_ID,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        AdminPermissionCacheVersion::updateOrCreate(
            ['admin_user_id' => self::TRANSLATOR_ADMIN_ID, 'scope_id' => self::CENTRAL_SCOPE_ID],
            [
                'id' => $this->stableId('pcv', self::TRANSLATOR_ADMIN_ID.':'.self::CENTRAL_SCOPE_ID),
                'version' => 2,
            ],
        );
    }

    private function seedResultOfficerAdmin(mixed $now): void
    {
        if (! Role::query()->where('id', self::RESULT_OFFICER_ROLE_ID)->exists()) {
            return;
        }

        AdminUser::updateOrCreate(
            ['id' => self::RESULT_OFFICER_ADMIN_ID],
            [
                'email' => self::RESULT_OFFICER_USERNAME.'@newpaotang.test',
                'username' => self::RESULT_OFFICER_USERNAME,
                'name' => 'Result Officer',
                'phone' => null,
                'password_hash' => Hash::make('1234'),
                'status' => 'active',
                'preferred_locale' => 'th-TH',
                'two_factor_enabled' => false,
            ],
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => self::RESULT_OFFICER_ADMIN_ID,
            'role_id' => self::RESULT_OFFICER_ROLE_ID,
            'scope_id' => self::CENTRAL_SCOPE_ID,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        AdminPermissionCacheVersion::updateOrCreate(
            ['admin_user_id' => self::RESULT_OFFICER_ADMIN_ID, 'scope_id' => self::CENTRAL_SCOPE_ID],
            [
                'id' => $this->stableId('pcv', self::RESULT_OFFICER_ADMIN_ID.':'.self::CENTRAL_SCOPE_ID),
                'version' => 2,
            ],
        );
    }

    private function seedLotteryUploaderAdmin(mixed $now): void
    {
        if (! Role::query()->where('id', self::LOTTERY_UPLOADER_ROLE_ID)->exists()) {
            return;
        }

        AdminUser::updateOrCreate(
            ['id' => self::LOTTERY_UPLOADER_ADMIN_ID],
            [
                'email' => self::LOTTERY_UPLOADER_USERNAME.'@newpaotang.test',
                'username' => self::LOTTERY_UPLOADER_USERNAME,
                'name' => 'Lottery Image Uploader',
                'phone' => null,
                'password_hash' => Hash::make('1234'),
                'status' => 'active',
                'preferred_locale' => 'th-TH',
                'two_factor_enabled' => false,
            ],
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => self::LOTTERY_UPLOADER_ADMIN_ID,
            'role_id' => self::LOTTERY_UPLOADER_ROLE_ID,
            'scope_id' => self::CENTRAL_SCOPE_ID,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        AdminPermissionCacheVersion::updateOrCreate(
            ['admin_user_id' => self::LOTTERY_UPLOADER_ADMIN_ID, 'scope_id' => self::CENTRAL_SCOPE_ID],
            [
                'id' => $this->stableId('pcv', self::LOTTERY_UPLOADER_ADMIN_ID.':'.self::CENTRAL_SCOPE_ID),
                'version' => 2,
            ],
        );
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

    private function retireLegacyAdminUsernames(): void
    {
        AdminUser::query()
            ->where('id', '!=', self::CENTRAL_ADMIN_ID)
            ->where(function ($query): void {
                $query->where('username', self::CENTRAL_USERNAME)
                    ->orWhere('email', self::CENTRAL_USERNAME.'@newpaotang.test');
            })
            ->update([
                'username' => null,
                'status' => 'inactive',
            ]);

        AdminUser::query()
            ->where('id', '!=', self::TRANSLATOR_ADMIN_ID)
            ->where(function ($query): void {
                $query->whereIn('username', [self::TRANSLATOR_USERNAME, 'translator_master'])
                    ->orWhereIn('email', [self::TRANSLATOR_USERNAME.'@newpaotang.test', 'translator_master@newpaotang.test']);
            })
            ->update([
                'username' => null,
                'status' => 'inactive',
            ]);

        AdminUser::query()
            ->where('id', '!=', self::RESULT_OFFICER_ADMIN_ID)
            ->where(function ($query): void {
                $query->where('username', self::RESULT_OFFICER_USERNAME)
                    ->orWhere('email', self::RESULT_OFFICER_USERNAME.'@newpaotang.test');
            })
            ->update([
                'username' => null,
                'status' => 'inactive',
            ]);

        AdminUser::query()
            ->where('id', '!=', self::LOTTERY_UPLOADER_ADMIN_ID)
            ->where(function ($query): void {
                $query->where('username', self::LOTTERY_UPLOADER_USERNAME)
                    ->orWhere('email', self::LOTTERY_UPLOADER_USERNAME.'@newpaotang.test');
            })
            ->update([
                'username' => null,
                'status' => 'inactive',
            ]);
    }
}
