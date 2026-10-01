<?php

namespace Tests\Feature;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BootstrapSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_seeder_creates_initial_system_without_demo_partners(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_platform_owner',
            'email' => 'superadmin@newpaotang.test',
            'username' => 'superadmin',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_translator',
            'email' => 'translator@newpaotang.test',
            'username' => 'translator',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_result_officer',
            'email' => 'result@newpaotang.test',
            'username' => 'result',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_lottery_uploader',
            'email' => 'uploader@newpaotang.test',
            'username' => 'uploader',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('roles', [
            'id' => 'rol_c_super_admin',
            'scope_type' => 'central',
            'code' => 'super_admin',
            'status' => 'active',
        ]);

        $this->assertSame(0, DB::table('partners')->count());
        $this->assertSame(0, DB::table('partner_tenants')->count());
        $this->assertSame(0, DB::table('partner_tenant_domains')->count());
        $this->assertDatabaseHas('system_languages', ['locale' => 'th-TH', 'status' => 'active', 'is_default' => true]);
        $this->assertDatabaseHas('system_languages', ['locale' => 'en-US', 'status' => 'active']);
        $this->assertDatabaseHas('system_translation_keys', ['surface' => 'back-office', 'translation_key' => 'menus.items.central.dashboard']);
        $this->assertDatabaseHas('system_translation_keys', ['surface' => 'back-office', 'translation_key' => 'account.changePassword']);
        $this->assertDatabaseHas('permissions', ['scope_type' => 'central', 'code' => 'storage_connection.manage']);
        $this->assertDatabaseHas('admin_menus', ['scope_type' => 'central', 'code' => 'storage_connections', 'route' => '/admin/central/storage-connections']);
        $this->assertDatabaseHas('admin_menus', ['scope_type' => 'central', 'code' => 'lottery_images', 'route' => '/admin/central/lottery-images']);
    }

    public function test_seeded_central_and_tenant_accounts_can_login(): void
    {
        $this->seed(DatabaseSeeder::class);

        $central = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'superadmin',
            'password' => '1234',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_platform_owner')
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertContains('partner.view', $central['scopes'][0]['permissions']);
        $this->assertContains('storage_connection.manage', $central['scopes'][0]['permissions']);

        $translator = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'translator',
            'password' => '1234',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_translator')
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertContains('translation.edit', $translator['scopes'][0]['permissions']);
        $this->assertContains('translation.request_deploy', $translator['scopes'][0]['permissions']);
        $this->assertNotContains('translation.approve_deploy', $translator['scopes'][0]['permissions']);

        $resultOfficer = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'result',
            'password' => '1234',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_result_officer')
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertContains('reward_entry.view', $resultOfficer['scopes'][0]['permissions']);
        $this->assertContains('reward_entry.submit', $resultOfficer['scopes'][0]['permissions']);
        $this->assertNotContains('reward_entry.resolve', $resultOfficer['scopes'][0]['permissions']);
        $this->assertNotContains('reward.view', $resultOfficer['scopes'][0]['permissions']);

        $uploader = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'uploader',
            'password' => '1234',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_lottery_uploader')
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertContains('stock.view', $uploader['scopes'][0]['permissions']);
        $this->assertContains('asset.manage', $uploader['scopes'][0]['permissions']);
        $this->assertNotContains('game.view', $uploader['scopes'][0]['permissions']);
        $this->assertNotContains('dashboard.view', $uploader['scopes'][0]['permissions']);
        $this->assertNotContains('stock.generate', $uploader['scopes'][0]['permissions']);
        $this->assertNotContains('reward.view', $uploader['scopes'][0]['permissions']);
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
