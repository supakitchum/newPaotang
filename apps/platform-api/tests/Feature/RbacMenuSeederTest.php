<?php

namespace Tests\Feature;

use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RbacMenuSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_default_permissions_seed_by_scope(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertSame(42, DB::table('permissions')->where('scope_type', 'central')->count());
        $this->assertSame(69, DB::table('permissions')->where('scope_type', 'tenant')->count());

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'central',
            'code' => 'partner.provision',
            'name' => 'Provision partner tenant defaults',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('permissions', [
            'scope_type' => 'tenant',
            'code' => 'support_access.impersonate_admin',
            'name' => 'Impersonate tenant admin with approval',
            'status' => 'active',
        ]);
    }

    public function test_default_menus_seed_with_documented_permission_codes(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertSame(23, DB::table('admin_menus')->where('scope_type', 'central')->count());
        $this->assertSame(31, DB::table('admin_menus')->where('scope_type', 'tenant')->count());

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partner_monitoring',
            'required_permission_code' => 'partner.monitoring.view',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'support_access_logs',
            'required_permission_code' => 'support_access.audit',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_generation',
            'label' => 'Stock Manager',
            'route' => '/admin/central/stock',
            'status' => 'active',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'master_stock',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_recall',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'central',
            'code' => 'partners',
            'route' => '/admin/central/partners',
        ]);

        $this->assertDatabaseHas('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'local_stock',
            'label' => 'Tenant Stock',
            'route' => '/admin/tenant/stock',
        ]);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'stock_sync',
        ]);
    }

    public function test_reseeding_does_not_duplicate_permissions_or_menus(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);
        $this->seed(DefaultRbacMenuSeeder::class);

        $seeder = new DefaultRbacMenuSeeder;

        $this->assertSame(count($seeder->permissions()), DB::table('permissions')->count());
        $this->assertSame(count($seeder->menus()), DB::table('admin_menus')->count());

        $this->assertSame(1, DB::table('permissions')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard.view')
            ->count());

        $this->assertSame(1, DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'dashboard.view')
            ->count());

        $this->assertSame(1, DB::table('admin_menus')
            ->where('scope_type', 'central')
            ->where('code', 'dashboard')
            ->count());

        $this->assertSame(1, DB::table('admin_menus')
            ->where('scope_type', 'tenant')
            ->where('code', 'dashboard')
            ->count());
    }

    public function test_reseeding_removes_retired_stock_recall_menu(): void
    {
        DB::table('admin_menus')->insert([
            'id' => 'men_retired_stock_recall',
            'scope_type' => 'central',
            'parent_id' => null,
            'code' => 'stock_recall',
            'label' => 'Stock Recall',
            'route' => '/admin/central/stock',
            'required_permission_code' => 'stock.recall',
            'sort_order' => 999,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'central',
            'code' => 'stock_recall',
        ]);
    }

    public function test_reseeding_removes_retired_tenant_stock_sync_menu_and_permission(): void
    {
        DB::table('permissions')->insert([
            'id' => 'per_retired_stock_sync',
            'scope_type' => 'tenant',
            'code' => 'stock.sync',
            'name' => 'Run or view stock sync',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_menus')->insert([
            'id' => 'men_retired_stock_sync',
            'scope_type' => 'tenant',
            'parent_id' => null,
            'code' => 'stock_sync',
            'label' => 'Stock Sync',
            'route' => '/admin/tenant/stock-sync',
            'required_permission_code' => 'stock.sync',
            'sort_order' => 999,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->seed(DefaultRbacMenuSeeder::class);

        $this->assertDatabaseMissing('admin_menus', [
            'scope_type' => 'tenant',
            'code' => 'stock_sync',
        ]);
        $this->assertDatabaseMissing('permissions', [
            'scope_type' => 'tenant',
            'code' => 'stock.sync',
        ]);
    }
}
