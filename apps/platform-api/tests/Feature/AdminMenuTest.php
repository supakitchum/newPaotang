<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    public function test_tenant_menu_includes_pending_review_badges(): void
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
            ['dashboard.view', 'topup.view'],
            'tenant_topup_menu_badge',
        );

        DB::table('customers')->insert([
            'id' => 'cus_menu_badge',
            'tenant_id' => 'ten_auth',
            'phone' => '0800000001',
            'name' => 'Menu Badge Customer',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('wallets')->insert([
            'id' => 'wal_menu_badge',
            'tenant_id' => 'ten_auth',
            'customer_id' => 'cus_menu_badge',
            'name' => 'Primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 0,
            'currency' => 'THB',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('topup_requests')->insert([
            [
                'id' => 'top_menu_pending',
                'tenant_id' => 'ten_auth',
                'customer_id' => 'cus_menu_badge',
                'wallet_id' => 'wal_menu_badge',
                'provider' => 'manual',
                'channel' => 'bank_transfer',
                'status' => 'pending',
                'amount' => 10000,
                'bonus_amount' => 0,
                'currency' => 'THB',
                'reference' => 'TOP-MENU-PENDING',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'top_menu_processing',
                'tenant_id' => 'ten_auth',
                'customer_id' => 'cus_menu_badge',
                'wallet_id' => 'wal_menu_badge',
                'provider' => 'manual',
                'channel' => 'bank_transfer',
                'status' => 'processing',
                'amount' => 20000,
                'bonus_amount' => 0,
                'currency' => 'THB',
                'reference' => 'TOP-MENU-PROCESSING',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'top_menu_done',
                'tenant_id' => 'ten_auth',
                'customer_id' => 'cus_menu_badge',
                'wallet_id' => 'wal_menu_badge',
                'provider' => 'manual',
                'channel' => 'bank_transfer',
                'status' => 'succeeded',
                'amount' => 30000,
                'bonus_amount' => 0,
                'currency' => 'THB',
                'reference' => 'TOP-MENU-DONE',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

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

        $topups = collect($response)->firstWhere('key', 'topups');

        $this->assertIsArray($topups);
        $this->assertSame('Review Queue', $topups['category'] ?? null);
        $this->assertSame(2, $topups['badge_count'] ?? null);
    }

    public function test_tenant_admin_cannot_access_another_tenant_menu(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createPartner('par_other');
        $this->createTenant('ten_other', 'par_other');
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

    public function test_partner_bo_rejects_central_routes_and_requires_matching_tenant_header(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_partner_a', 'partner-a', 'Partner A');
        $this->createTenant('ten_partner_a', 'par_partner_a', 'partner-a', 'Partner A Tenant');
        $this->createTenantDomain('dom_partner_a', 'par_partner_a', 'ten_partner_a', 'partner-a.test');
        $this->createPartner('par_partner_b', 'partner-b', 'Partner B');
        $this->createTenant('ten_partner_b', 'par_partner_b', 'partner-b', 'Partner B Tenant');
        $this->createTenantDomain('dom_partner_b', 'par_partner_b', 'ten_partner_b', 'partner-b.test');

        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $this->createAdmin('adm_tenant', 'tenant-a@example.test');
        $this->createAdminScope('scp_partner_a', 'tenant', 'ten_partner_a', 'par_partner_a');
        $this->assignRoleWithPermissions(
            'adm_tenant',
            'scp_partner_a',
            'tenant',
            'ten_partner_a',
            ['dashboard.view', 'order.view'],
            'tenant_partner_a_dashboard_orders',
        );

        $central = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($central['access_token'])
            ->getJson('http://bo.partner-a.test/api/v1/admin/central/menu', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $tenant = $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'tenant-a@example.test',
            'password' => 'secret-password',
        ])
            ->assertOk()
            ->assertJsonCount(1, 'scopes')
            ->json();

        $this->withToken($tenant['access_token'])
            ->getJson('http://bo.partner-a.test/api/v1/admin/tenant/menu', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_partner_b',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tenant['access_token'])
            ->getJson('http://bo.partner-a.test/api/v1/admin/tenant/menu', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_partner_a',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.key', 'dashboard');
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
