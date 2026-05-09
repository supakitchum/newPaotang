<?php

namespace Tests\Feature;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BootstrapSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_seeder_creates_bootstrap_admin_and_three_demo_tenants(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_platform_owner',
            'email' => 'admin@newpaotang.test',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('roles', [
            'id' => 'rol_c_super_admin',
            'scope_type' => 'central',
            'code' => 'super_admin',
            'status' => 'active',
        ]);

        $this->assertSame(3, DB::table('partners')->where('code', 'like', 'demo_%')->count());
        $this->assertSame(3, DB::table('partner_tenants')->where('code', 'like', 'demo_%')->count());
        $this->assertSame(3, DB::table('partner_tenant_domains')->where('host', 'like', '%.newpaotang.test')->where('status', 'active')->count());

        foreach (['ten_demo_alpha', 'ten_demo_beta', 'ten_demo_gamma'] as $tenantId) {
            $this->assertDatabaseHas('partner_tenant_settings', ['tenant_id' => $tenantId]);
            $this->assertDatabaseHas('partner_tenant_themes', ['tenant_id' => $tenantId]);
            $this->assertDatabaseHas('partner_tenant_maintenance_settings', ['tenant_id' => $tenantId, 'status' => 'inactive']);
            $this->assertDatabaseHas('partner_tenant_deployment_profiles', ['tenant_id' => $tenantId, 'status' => 'active']);
        }

        foreach (['par_demo_alpha', 'par_demo_beta', 'par_demo_gamma'] as $partnerId) {
            $this->assertDatabaseHas('partner_monitoring_profiles', ['partner_id' => $partnerId, 'status' => 'active']);
            $this->assertDatabaseHas('partner_alert_policies', ['partner_id' => $partnerId, 'policy_key' => 'default_health', 'status' => 'active']);
            $this->assertDatabaseHas('partner_health_checks', ['partner_id' => $partnerId, 'check_key' => 'site_config']);
            $this->assertDatabaseHas('partner_usage_meters', ['partner_id' => $partnerId, 'meter_key' => 'api_requests', 'status' => 'active']);
            $this->assertDatabaseHas('partner_usage_meters', ['partner_id' => $partnerId, 'meter_key' => 'queue_jobs', 'status' => 'active']);
        }
    }

    public function test_seeded_central_and_tenant_accounts_can_login(): void
    {
        $this->seed(DatabaseSeeder::class);

        $central = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'admin@newpaotang.test',
            'password' => 'NewPaotangAdmin!2026',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_platform_owner')
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertContains('partner.view', $central['scopes'][0]['permissions']);

        $tenant = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@alpha.newpaotang.test',
            'password' => 'NewPaotangTenant!2026',
            'scope' => 'tenant',
            'tenant_id' => 'ten_demo_alpha',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_demo_alpha_owner')
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_demo_alpha')
            ->json();

        $this->assertContains('order.view', $tenant['scopes'][0]['permissions']);
    }

    public function test_seeded_menu_routes_support_back_office_navigation(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partners',
            'route' => '/admin/central/partners',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'orders',
            'route' => '/admin/tenant/orders',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'agents',
            'route' => '/admin/tenant/growth/agents',
        ]);
    }

    public function test_database_seeder_is_idempotent(): void
    {
        $this->seed(DatabaseSeeder::class);

        $counts = [
            'admin_users' => DB::table('admin_users')->count(),
            'admin_scopes' => DB::table('admin_scopes')->count(),
            'roles' => DB::table('roles')->count(),
            'role_permissions' => DB::table('role_permissions')->count(),
            'role_menus' => DB::table('role_menus')->count(),
            'admin_user_roles' => DB::table('admin_user_roles')->count(),
            'partners' => DB::table('partners')->count(),
            'partner_tenants' => DB::table('partner_tenants')->count(),
            'partner_tenant_domains' => DB::table('partner_tenant_domains')->count(),
        ];

        $this->seed(DatabaseSeeder::class);

        foreach ($counts as $table => $count) {
            $this->assertSame($count, DB::table($table)->count(), $table.' count changed after reseeding.');
        }
    }
}
