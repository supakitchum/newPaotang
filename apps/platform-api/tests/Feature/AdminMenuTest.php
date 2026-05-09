<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminMenuTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_central_menu_requires_central_scope_and_returns_permission_allowed_items(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $login = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $response = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/menu', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->json('data');

        $this->assertSame(['dashboard'], array_column($response, 'key'));
        $this->assertSame('Dashboard', $response[0]['category']);
        $this->assertSame('ri-dashboard-line', $response[0]['icon']);
        $this->assertArrayHasKey('label', $response[0]);
    }

    public function test_tenant_menu_requires_tenant_scope_and_requested_tenant(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions(
            'adm_tenant',
            'scp_tenant',
            'tenant',
            'ten_auth',
            ['dashboard.view', 'order.view'],
            'tenant_dashboard_orders',
        );

        $login = $this->loginAdmin([
            'email' => 'tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ]);

        $response = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/menu', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->json('data');

        $this->assertSame(['dashboard', 'orders'], array_column($response, 'key'));
        $this->assertSame('Dashboard', $response[0]['category']);
        $this->assertSame('Store Operations', $response[1]['category']);
        $this->assertSame('ri-receipt-line', $response[1]['icon']);
        $this->assertArrayHasKey('route', $response[1]);
    }

    public function test_tenant_admin_cannot_access_another_tenant_menu(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createTenant('ten_other');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions('adm_tenant', 'scp_tenant', 'tenant', 'ten_auth', ['dashboard.view'], 'tenant_dashboard');

        $login = $this->loginAdmin([
            'email' => 'tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/menu', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_other',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_central_admin_cannot_use_tenant_menu_with_central_token(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $login = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/menu', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_menu_default_deny_returns_empty_tree_without_permissions(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, [], 'central_empty');

        $login = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/menu', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data', []);
    }
}
