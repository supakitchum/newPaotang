<?php

namespace Tests\Feature;

use App\Modules\Rbac\Services\MenuService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RbacFoundationTest extends TestCase
{
    use RefreshDatabase;

    public function test_permission_checks_default_to_deny(): void
    {
        $allowed = app(PermissionService::class)->adminHasPermission(
            'adm_missing',
            'tenant',
            'scp_missing',
            'dashboard.view',
            'ten_missing',
        );

        $this->assertFalse($allowed);
    }

    public function test_central_and_tenant_scopes_are_separated(): void
    {
        $this->seedRbac();

        $permissions = app(PermissionService::class);

        $this->assertTrue($permissions->adminHasPermission('adm_test', 'central', 'scp_central', 'dashboard.view'));
        $this->assertFalse($permissions->adminHasPermission('adm_test', 'tenant', 'scp_tenant', 'dashboard.view', 'ten_test'));
    }

    public function test_menu_service_is_permission_driven(): void
    {
        $this->seedRbac();

        DB::table('admin_menus')->insert([
            [
                'id' => 'men_dashboard',
                'scope_type' => 'central',
                'parent_id' => null,
                'code' => 'dashboard',
                'label' => 'Dashboard',
                'route' => '/central/dashboard',
                'required_permission_code' => 'dashboard.view',
                'sort_order' => 1,
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'men_roles',
                'scope_type' => 'central',
                'parent_id' => null,
                'code' => 'roles_permissions',
                'label' => 'Roles',
                'route' => '/central/roles',
                'required_permission_code' => 'role.manage',
                'sort_order' => 2,
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        $menus = app(MenuService::class)->allowedMenusForAdmin('adm_test', 'central', 'scp_central');

        $this->assertSame(['dashboard'], array_column($menus, 'code'));
    }

    private function seedRbac(): void
    {
        DB::table('partners')->insert([
            'id' => 'par_test',
            'code' => 'partner-test',
            'name' => 'Partner Test',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => 'ten_test',
            'partner_id' => 'par_test',
            'code' => 'tenant-test',
            'name' => 'Tenant Test',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_users')->insert([
            'id' => 'adm_test',
            'email' => 'admin@example.test',
            'password_hash' => 'hash',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_scopes')->insert([
            [
                'id' => 'scp_central',
                'scope_type' => 'central',
                'tenant_id' => null,
                'partner_id' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'scp_tenant',
                'scope_type' => 'tenant',
                'tenant_id' => 'ten_test',
                'partner_id' => 'par_test',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        DB::table('roles')->insert([
            'id' => 'rol_central',
            'scope_type' => 'central',
            'tenant_id' => null,
            'code' => 'central_admin',
            'name' => 'Central Admin',
            'status' => 'active',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('permissions')->insert([
            'id' => 'per_dashboard',
            'scope_type' => 'central',
            'code' => 'dashboard.view',
            'name' => 'View dashboard',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('role_permissions')->insert([
            'role_id' => 'rol_central',
            'permission_id' => 'per_dashboard',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_user_roles')->insert([
            'admin_user_id' => 'adm_test',
            'role_id' => 'rol_central',
            'scope_id' => 'scp_central',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
