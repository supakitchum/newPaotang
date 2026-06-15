<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use App\Modules\CentralStock\Events\StockCoverageUpdated;
use App\Modules\CentralStock\Events\StockTableUpdated;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class CentralAllocationTest extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_CentralAllocation_retires_requested_count_and_creates_percent_snapshot_without_physical_rows(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_alloc', 'ten_alloc');
        $this->insertGame('gam_alloc', 'open');
        $this->insertVirtualSupplyProfile('gam_alloc', 10);
        $this->insertStockItems('gam_alloc', 5);

        $limitedLogin = $this->createCentralSession(['stock.view'], 'adm_alloc_limited', 'alloc-limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->getJson('/api/v1/admin/central/allocations', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->createCentralSession(['stock.allocate'], 'adm_alloc', 'alloc@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 3,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-requested-count-retired',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.requested_count.0', 'The requested_count field is retired for allocation create. Use allocation_percent.');

        $allocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'allocation_percent' => 30,
                'reason' => 'initial percent',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-create-main',
                'X-Request-Id' => 'req-allocation-create',
            ])
            ->assertAccepted()
            ->assertJsonPath('partner_id', 'par_alloc')
            ->assertJsonPath('tenant_id', 'ten_alloc')
            ->assertJsonPath('game_id', 'gam_alloc')
            ->assertJsonPath('status', 'allocated')
            ->assertJsonPath('allocation_percent', 30)
            ->assertJsonPath('allocated_count', 3)
            ->assertJsonPath('remaining_count', 3)
            ->json();

        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.allocated.v1',
            'partner_id' => 'par_alloc',
            'tenant_id' => 'ten_alloc',
            'game_id' => 'gam_alloc',
            'aggregate_id' => $allocation['id'],
            'idempotency_key' => 'allocation-create-main',
            'correlation_id' => 'req-allocation-create',
            'status' => 'pending',
        ]);
        $this->assertSame(0, DB::table('stock_items')->where('allocation_id', $allocation['id'])->count());
        $this->assertSame(5, DB::table('stock_items')->where('game_id', 'gam_alloc')->where('status', 'available')->count());
        $this->assertSame(0, DB::table('partner_stock_allocation_items')->where('allocation_id', $allocation['id'])->count());
        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_alloc',
            'partner_id' => 'par_alloc',
            'tenant_id' => 'ten_alloc',
            'percent_basis_points' => 3000,
            'status' => 'active',
        ]);

        $sameAllocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'allocation_percent' => 30,
                'reason' => 'initial percent',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-create-main',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($allocation['id'], $sameAllocation['id']);
        $this->assertSame(1, DB::table('partner_stock_allocations')->count());

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'allocation_percent' => 40,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-create-main',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocations/'.$allocation['id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $allocation['id']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocations?partner_id=par_alloc&tenant_id=ten_alloc&game_id=gam_alloc', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $allocation['id']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/'.$allocation['id'].'/cancel', [
                'reason' => 'operator cancelled before sale',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-cancel-main',
                'X-Request-Id' => 'req-allocation-cancel',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled')
            ->assertJsonPath('allocated_count', 0)
            ->assertJsonPath('remaining_count', 0)
            ->assertJsonPath('active_partner_percent', 0);

        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_alloc',
            'partner_id' => 'par_alloc',
            'tenant_id' => 'ten_alloc',
            'percent_basis_points' => 0,
            'status' => 'cancelled',
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_alloc&available_for_create=1&q=par_alloc', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.partner_id', 'par_alloc');

        DB::table('games')->where('id', 'gam_alloc')->update(['status' => 'closed', 'updated_at' => now()]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-closed-game',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference an open game.');

        DB::table('games')->where('id', 'gam_alloc')->update(['status' => 'open', 'updated_at' => now()]);
        DB::table('partner_tenants')->where('id', 'ten_alloc')->update(['status' => 'suspended', 'updated_at' => now()]);
        $this->insertActivePartnerTenant('par_alloc_suspended_check', 'ten_alloc_suspended_check');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc_suspended_check',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-suspended-tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.tenant_id.0', 'The tenant_id field must reference an active tenant for an active partner.');
    }

    public function test_CentralAllocation_requires_latest_open_game_for_options_and_create(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_alloc_latest', 'ten_alloc_latest');
        $this->insertGame('gam_alloc_old', 'open');
        $this->insertGame('gam_alloc_latest', 'open');
        $this->insertGame('gam_alloc_closed', 'closed');
        $this->insertVirtualSupplyProfile('gam_alloc_old', 10);
        $this->insertVirtualSupplyProfile('gam_alloc_latest', 20);

        DB::table('games')->where('id', 'gam_alloc_old')->update([
            'draw_at' => now()->addDay(),
            'created_at' => now()->subDay(),
            'updated_at' => now(),
        ]);
        DB::table('games')->where('id', 'gam_alloc_latest')->update([
            'draw_at' => now()->addDays(2),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('games')->where('id', 'gam_alloc_closed')->update([
            'draw_at' => now()->addDays(3),
            'created_at' => now()->addDay(),
            'updated_at' => now(),
        ]);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_alloc_latest', 'alloc-latest@example.test');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/games', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.game_id', 'gam_alloc_latest')
            ->assertJsonPath('data.0.generated_supply_count', 20)
            ->assertJsonPath('data.0.existing_allocation_percent', 0)
            ->assertJsonPath('data.0.existing_remaining_count', 20);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_alloc_old&available_for_create=1', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc_latest',
                'tenant_id' => 'ten_alloc_latest',
                'game_id' => 'gam_alloc_old',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-old-open-game',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference the latest open game.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc_latest',
                'tenant_id' => 'ten_alloc_latest',
                'game_id' => 'gam_alloc_closed',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-closed-latest-game',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference an open game.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc_latest',
                'tenant_id' => 'ten_alloc_latest',
                'game_id' => 'gam_alloc_latest',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-latest-open-game',
            ])
            ->assertAccepted()
            ->assertJsonPath('game_id', 'gam_alloc_latest')
            ->assertJsonPath('allocation_percent', 10)
            ->assertJsonPath('allocated_count', 2);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/games', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.game_id', 'gam_alloc_latest')
            ->assertJsonPath('data.0.existing_allocation_percent', 10)
            ->assertJsonPath('data.0.existing_allocated_count', 2)
            ->assertJsonPath('data.0.existing_remaining_count', 18);
    }

    public function test_CentralAllocation_percent_workflow_options_recall_all_redistribute_and_validation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_percent_a', 'ten_percent_a');
        $this->insertActivePartnerTenant('par_percent_b', 'ten_percent_b');
        $this->insertGame('gam_percent', 'open');
        $this->insertVirtualSupplyProfile('gam_percent', 10);
        DB::table('partners')->where('id', 'par_percent_a')->update([
            'stock_percent_basis_points' => 2500,
            'updated_at' => now(),
        ]);

        DB::table('partners')->insert([
            'id' => 'par_no_tenant',
            'code' => 'par_no_tenant',
            'name' => 'Partner no tenant',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_percent', 'percent@example.test');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_percent&q=percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.partner_id', 'par_percent_a')
            ->assertJsonPath('data.0.single_tenant_id', 'ten_percent_a')
            ->assertJsonPath('data.0.active_tenant_count', 1)
            ->assertJsonPath('data.0.stock_percent', 25)
            ->assertJsonPath('data.0.default_allocation_percent', 25)
            ->assertJsonPath('data.0.allocation_percent', null)
            ->assertJsonPath('data.0.existing_allocation_percent', 0)
            ->assertJsonPath('data.0.existing_remaining_count', 10);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/tenants?partner_id=par_percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.tenant_id', 'ten_percent_a')
            ->assertJsonPath('data.0.partner_id', 'par_percent_a');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_percent&available_for_create=1&q=percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.partner_id', 'par_percent_a')
            ->assertJsonPath('data.0.single_tenant_id', 'ten_percent_a')
            ->assertJsonPath('data.0.stock_percent', 25)
            ->assertJsonPath('data.0.default_allocation_percent', 25)
            ->assertJsonPath('data.0.existing_allocation_percent', 0)
            ->assertJsonPath('data.0.existing_remaining_count', 10);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/tenants?game_id=gam_percent&partner_id=par_percent_a&available_for_create=1', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.tenant_id', 'ten_percent_a');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/games?q=gam_percent', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.game_id', 'gam_percent')
            ->assertJsonPath('data.0.generated_supply_count', 10);

        $allocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_percent_a',
                'game_id' => 'gam_percent',
                'allocation_percent' => 30,
                'reason' => 'percent allocation',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-a',
                'X-Request-Id' => 'req-allocation-percent-a',
            ])
            ->assertAccepted()
            ->assertJsonPath('partner_id', 'par_percent_a')
            ->assertJsonPath('partner_code', 'par_percent_a')
            ->assertJsonPath('tenant_id', 'ten_percent_a')
            ->assertJsonPath('tenant_name', 'Tenant ten_percent_a')
            ->assertJsonPath('game_id', 'gam_percent')
            ->assertJsonPath('game_name', 'Game gam_percent')
            ->assertJsonPath('status', 'allocated')
            ->assertJsonPath('allocation_percent', 30)
            ->assertJsonPath('allocation_percent_basis_points', 3000)
            ->assertJsonPath('allocated_count', 3)
            ->assertJsonPath('remaining_count', 3)
            ->assertJsonPath('recalled_count', 0)
            ->json();

        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_percent',
            'partner_id' => 'par_percent_a',
            'tenant_id' => 'ten_percent_a',
            'percent_basis_points' => 3000,
            'status' => 'active',
        ]);
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_percent')->count());
        $this->assertSame(0, DB::table('partner_stock_allocation_items')->where('allocation_id', $allocation['id'])->count());

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_percent_a',
                'game_id' => 'gam_percent',
                'allocation_percent' => 30,
                'reason' => 'percent allocation',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-a',
            ])
            ->assertAccepted()
            ->assertJsonPath('id', $allocation['id']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_percent_a',
                'game_id' => 'gam_percent',
                'allocation_percent' => 40,
                'reason' => 'percent allocation',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-a',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_percent&available_for_create=1&q=percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(0, 'data');

        DB::table('stock_partner_distributions')
            ->where('game_id', 'gam_percent')
            ->where('partner_id', 'par_percent_a')
            ->update([
                'percent_basis_points' => 9000,
                'updated_at' => now(),
            ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/partners?game_id=gam_percent&q=percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.stock_percent', 25)
            ->assertJsonPath('data.0.default_allocation_percent', 25)
            ->assertJsonPath('data.0.allocation_percent', 30)
            ->assertJsonPath('data.0.remaining_count', 3)
            ->assertJsonPath('data.0.existing_allocation_percent', 30)
            ->assertJsonPath('data.0.existing_allocated_count', 3)
            ->assertJsonPath('data.0.existing_remaining_count', 7);

        DB::table('stock_partner_distributions')
            ->where('game_id', 'gam_percent')
            ->where('partner_id', 'par_percent_a')
            ->update([
                'percent_basis_points' => 3000,
                'updated_at' => now(),
            ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/tenants?game_id=gam_percent&partner_id=par_percent_a&available_for_create=1', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_percent_a',
                'game_id' => 'gam_percent',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-a-duplicate-tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.tenant_id.0', 'This partner tenant already has an active allocation for this game.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_percent_b',
                'tenant_id' => 'ten_percent_b',
                'game_id' => 'gam_percent',
                'allocation_percent' => 80,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-over-total',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.allocation_percent.0', 'The total active partner allocation percent for this game may not exceed 100.');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/allocations/partner-percent', [
                'partner_id' => 'par_percent_b',
                'tenant_id' => 'ten_percent_b',
                'game_id' => 'gam_percent',
                'allocation_percent' => 70,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-percent-b',
            ])
            ->assertOk()
            ->assertJsonPath('partner_id', 'par_percent_b')
            ->assertJsonPath('allocation_percent', 70)
            ->assertJsonPath('target_allocation_count', 7)
            ->assertJsonPath('remaining_count', 7);

        DB::table('virtual_stock_counters')->insert([
            'id' => 'vsc_percent_b_used',
            'game_id' => 'gam_percent',
            'scope_type' => 'partner',
            'scope_id' => 'par_percent_b',
            'dimension' => 'full_number',
            'value' => '000001',
            'reserved_count' => 8,
            'sold_count' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/allocations/partner-percent', [
                'partner_id' => 'par_percent_b',
                'tenant_id' => 'ten_percent_b',
                'game_id' => 'gam_percent',
                'allocation_percent' => 50,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-percent-b-too-low',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.allocation_percent.0', 'The allocation_percent cannot be below already reserved or sold virtual stock for this partner.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_no_tenant',
                'game_id' => 'gam_percent',
                'allocation_percent' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-no-tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.tenant_id.0', 'The selected partner has no active tenant.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/'.$allocation['id'].'/recall-all', [
                'reason' => 'full recall',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-recall-all',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'recalled')
            ->assertJsonPath('remaining_count', 0)
            ->assertJsonPath('recalled_count', 3);

        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_percent',
            'partner_id' => 'par_percent_a',
            'percent_basis_points' => 0,
            'status' => 'recalled',
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/'.$allocation['id'].'/redistribute', [
                'reason' => 'redistribute after recall',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-redistribute',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'allocated')
            ->assertJsonPath('allocation_percent', 30)
            ->assertJsonPath('allocated_count', 3)
            ->assertJsonPath('remaining_count', 3)
            ->assertJsonPath('recalled_count', 0);

        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_percent',
            'partner_id' => 'par_percent_a',
            'percent_basis_points' => 3000,
            'status' => 'active',
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/'.$allocation['id'].'/redistribute', [
                'reason' => 'redistribute without recall',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-percent-redistribute-again',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');
    }

    public function test_CentralAllocation_can_open_allocations_for_all_active_partners(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_bulk_a', 'ten_bulk_a');
        $this->insertActivePartnerTenant('par_bulk_b', 'ten_bulk_b');
        $this->insertActivePartnerTenant('par_bulk_zero', 'ten_bulk_zero');
        DB::table('partners')->insert([
            'id' => 'par_bulk_no_tenant',
            'code' => 'par_bulk_no_tenant',
            'name' => 'Partner par_bulk_no_tenant',
            'type' => 'partner_store',
            'status' => 'active',
            'stock_percent_basis_points' => 1000,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('partners')->where('id', 'par_bulk_a')->update([
            'stock_percent_basis_points' => 4000,
            'updated_at' => now(),
        ]);
        DB::table('partners')->where('id', 'par_bulk_b')->update([
            'stock_percent_basis_points' => 3000,
            'updated_at' => now(),
        ]);
        $this->insertGame('gam_bulk_alloc', 'open');
        $this->insertVirtualSupplyProfile('gam_bulk_alloc', 100);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_bulk_alloc', 'bulk-alloc@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/open-all-partners', [
                'game_id' => 'gam_bulk_alloc',
                'reason' => 'open all partners for this draw',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-open-all-partners',
                'X-Request-Id' => 'req-open-all-partners',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('game_id', 'gam_bulk_alloc')
            ->assertJsonPath('created_count', 2)
            ->assertJsonPath('skipped_count', 2)
            ->assertJsonPath('created.0.partner_id', 'par_bulk_a')
            ->assertJsonPath('created.0.tenant_id', 'ten_bulk_a')
            ->assertJsonPath('created.0.allocation_percent', 40)
            ->assertJsonPath('created.0.allocated_count', 40)
            ->assertJsonPath('created.1.partner_id', 'par_bulk_b')
            ->assertJsonPath('created.1.tenant_id', 'ten_bulk_b')
            ->assertJsonPath('created.1.allocation_percent', 30)
            ->assertJsonPath('created.1.allocated_count', 30)
            ->assertJsonPath('skipped.0.partner_id', 'par_bulk_no_tenant')
            ->assertJsonPath('skipped.0.reason', 'no_active_tenant')
            ->assertJsonPath('skipped.1.partner_id', 'par_bulk_zero')
            ->assertJsonPath('skipped.1.reason', 'missing_allocation_percent');

        $this->assertDatabaseHas('partner_stock_allocations', [
            'partner_id' => 'par_bulk_a',
            'tenant_id' => 'ten_bulk_a',
            'game_id' => 'gam_bulk_alloc',
            'allocation_percent_basis_points' => 4000,
            'allocated_count' => 40,
            'status' => 'allocated',
        ]);
        $this->assertDatabaseHas('partner_stock_allocations', [
            'partner_id' => 'par_bulk_b',
            'tenant_id' => 'ten_bulk_b',
            'game_id' => 'gam_bulk_alloc',
            'allocation_percent_basis_points' => 3000,
            'allocated_count' => 30,
            'status' => 'allocated',
        ]);
        $this->assertSame(2, DB::table('partner_stock_allocations')->where('game_id', 'gam_bulk_alloc')->count());
        $this->assertSame(2, DB::table('sync_outbox')->where('event_type', 'stock.allocated.v1')->where('game_id', 'gam_bulk_alloc')->count());
        $this->assertSame(7000, (int) DB::table('stock_partner_distributions')->where('game_id', 'gam_bulk_alloc')->sum('percent_basis_points'));
    }

    public function test_CentralAllocation_open_all_partners_accepts_reviewed_percent_list_and_blocks_over_100_total(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_bulk_manual_existing', 'ten_bulk_manual_existing');
        $this->insertActivePartnerTenant('par_bulk_manual_a', 'ten_bulk_manual_a');
        $this->insertActivePartnerTenant('par_bulk_manual_b', 'ten_bulk_manual_b');
        $this->insertGame('gam_bulk_manual', 'open');
        $this->insertVirtualSupplyProfile('gam_bulk_manual', 100);

        DB::table('stock_partner_distributions')->insert([
            'id' => 'spd_bulk_manual_existing',
            'game_id' => 'gam_bulk_manual',
            'partner_id' => 'par_bulk_manual_existing',
            'tenant_id' => 'ten_bulk_manual_existing',
            'percent_basis_points' => 6000,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_bulk_manual_existing',
            'partner_id' => 'par_bulk_manual_existing',
            'tenant_id' => 'ten_bulk_manual_existing',
            'game_id' => 'gam_bulk_manual',
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => 60,
            'allocation_percent_basis_points' => 6000,
            'supply_layer_ids_json' => json_encode([], JSON_THROW_ON_ERROR),
            'allocated_count' => 60,
            'recalled_count' => 0,
            'idempotency_key' => null,
            'payload_hash' => null,
            'created_by_admin_id' => null,
            'reason' => 'existing allocation',
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_bulk_manual', 'bulk-manual@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/open-all-partners', [
                'game_id' => 'gam_bulk_manual',
                'allocations' => [
                    ['partner_id' => 'par_bulk_manual_a', 'tenant_id' => 'ten_bulk_manual_a', 'allocation_percent' => 25],
                    ['partner_id' => 'par_bulk_manual_b', 'tenant_id' => 'ten_bulk_manual_b', 'allocation_percent' => 20],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-open-all-partners-manual-over',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.allocations.0', 'The total active partner allocation percent for this game may not exceed 100.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/open-all-partners', [
                'game_id' => 'gam_bulk_manual',
                'allocations' => [
                    ['partner_id' => 'par_bulk_manual_a', 'tenant_id' => 'ten_bulk_manual_a', 'allocation_percent' => 25],
                    ['partner_id' => 'par_bulk_manual_b', 'tenant_id' => 'ten_bulk_manual_b', 'allocation_percent' => 15],
                ],
                'reason' => 'reviewed percentages',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-open-all-partners-manual-valid',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('created_count', 2)
            ->assertJsonPath('skipped_count', 0)
            ->assertJsonPath('created.0.partner_id', 'par_bulk_manual_a')
            ->assertJsonPath('created.0.allocation_percent', 25)
            ->assertJsonPath('created.0.allocated_count', 25)
            ->assertJsonPath('created.1.partner_id', 'par_bulk_manual_b')
            ->assertJsonPath('created.1.allocation_percent', 15)
            ->assertJsonPath('created.1.allocated_count', 15);

        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_bulk_manual',
            'partner_id' => 'par_bulk_manual_a',
            'tenant_id' => 'ten_bulk_manual_a',
            'percent_basis_points' => 2500,
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('stock_partner_distributions', [
            'game_id' => 'gam_bulk_manual',
            'partner_id' => 'par_bulk_manual_b',
            'tenant_id' => 'ten_bulk_manual_b',
            'percent_basis_points' => 1500,
            'status' => 'active',
        ]);
        $this->assertSame(10000, (int) DB::table('stock_partner_distributions')->where('game_id', 'gam_bulk_manual')->sum('percent_basis_points'));
    }

    public function test_CentralAllocation_requested_count_is_rejected_even_when_old_idempotency_key_exists(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_replay', 'ten_replay');
        $this->insertGame('gam_replay', 'open');
        $this->insertStockItems('gam_replay', 2);
        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_replay_legacy',
            'partner_id' => 'par_replay',
            'tenant_id' => 'ten_replay',
            'game_id' => 'gam_replay',
            'quota_id' => null,
            'status' => 'pending',
            'requested_count' => 2,
            'allocation_percent_basis_points' => null,
            'allocated_count' => 0,
            'recalled_count' => 0,
            'idempotency_key' => 'allocation-replay-exhausts-quota',
            'payload_hash' => hash('sha256', 'legacy-requested-count'),
            'created_by_admin_id' => null,
            'reason' => 'legacy replay seed',
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_replay', 'replay@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_replay',
                'tenant_id' => 'ten_replay',
                'game_id' => 'gam_replay',
                'requested_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-replay-exhausts-quota',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.requested_count.0', 'The requested_count field is retired for allocation create. Use allocation_percent.');

        $this->assertSame(1, DB::table('partner_stock_allocations')->where('game_id', 'gam_replay')->count());
        $this->assertSame(0, DB::table('partner_stock_allocation_items')->where('allocation_id', 'alc_replay_legacy')->count());
        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_replay')->where('status', 'available')->count());
    }

    public function test_CentralAllocation_percent_create_exposes_partner_virtual_inventory_without_physical_assignment(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_inventory', 'ten_inventory');
        $this->insertGame('gam_inventory', 'open');
        $this->insertBaseLotteryNumbers(['000001', '000002', '000003', '000004']);
        $this->insertVirtualSupplyProfile('gam_inventory', 4);

        $login = $this->createCentralSession(['stock.allocate', 'stock.view'], 'adm_inventory', 'inventory@example.test');

        $allocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_inventory',
                'tenant_id' => 'ten_inventory',
                'game_id' => 'gam_inventory',
                'allocation_percent' => 100,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-inventory-visible',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 4)
            ->json();

        $this->assertSame(0, DB::table('stock_items')->where('partner_id', 'par_inventory')->count());
        $this->assertSame(0, DB::table('stock_items')->where('allocation_id', $allocation['id'])->count());

        $stock = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?grouped=1&game_id=gam_inventory&partner_id=par_inventory&tenant_id=ten_inventory&allocation_id='.$allocation['id'].'&status=allocated&limit=20', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.scope_type', 'partner')
            ->assertJsonPath('meta.scope_id', 'par_inventory')
            ->json('data');

        $this->assertCount(4, $stock);
        $this->assertSame(4, array_sum(array_map(fn (array $row): int => (int) $row['total_count'], $stock)));
        $this->assertSame(['par_inventory'], array_values(array_unique(array_map(fn (array $row): ?string => $row['partner_id'], $stock))));
    }

    public function test_CentralAllocation_percent_create_broadcasts_single_refresh_invalidation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_realtime_alloc', 'ten_realtime_alloc');
        $this->insertGame('gam_realtime_alloc', 'open');
        $this->insertVirtualSupplyProfile('gam_realtime_alloc', 100);
        Event::fake([StockCoverageUpdated::class, StockTableUpdated::class]);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_realtime_alloc', 'realtime-alloc@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_realtime_alloc',
                'tenant_id' => 'ten_realtime_alloc',
                'game_id' => 'gam_realtime_alloc',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-realtime-refresh',
            ])
            ->assertAccepted()
            ->assertJsonPath('partner_id', 'par_realtime_alloc')
            ->assertJsonPath('tenant_id', 'ten_realtime_alloc');

        Event::assertDispatchedTimes(StockCoverageUpdated::class, 1);
        Event::assertDispatched(StockCoverageUpdated::class, fn (StockCoverageUpdated $event): bool => (
            ($event->payload['game_id'] ?? null) === 'gam_realtime_alloc'
            && ($event->payload['refresh_required'] ?? null) === true
            && ($event->payload['reason'] ?? null) === 'stock_supply_changed'
            && ! array_key_exists('dimension', $event->payload)
            && ! array_key_exists('number', $event->payload)
        ));
        Event::assertDispatchedTimes(StockTableUpdated::class, 1);
        Event::assertDispatched(StockTableUpdated::class, function (StockTableUpdated $event): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'stock.table.updated'
                && ($event->payload['game_id'] ?? null) === 'gam_realtime_alloc'
                && ($event->payload['refresh_required'] ?? null) === true
                && ($event->payload['reason'] ?? null) === 'stock_supply_changed'
                && in_array('private-admin.central.stock.table.game.gam_realtime_alloc', $channels, true);
        });
    }

    public function test_CentralAllocation_percent_snapshots_supply_layers_and_leaves_topup_unassigned_until_new_allocation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_snapshot_a', 'ten_snapshot_a');
        $this->insertActivePartnerTenant('par_snapshot_b', 'ten_snapshot_b');
        $this->insertGame('gam_snapshot', 'open');
        $this->insertBaseLotteryNumbers(['000001', '000002', '000003', '000004']);
        $this->insertVirtualSupplyProfile('gam_snapshot', 4);
        $this->insertVirtualSupplyLayer('gam_snapshot', 'vsl_snapshot_initial', 'snapshot-initial-seed', 4);

        $login = $this->createCentralSession(['stock.allocate', 'stock.view'], 'adm_snapshot', 'snapshot@example.test');

        $allocationA = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_snapshot_a',
                'tenant_id' => 'ten_snapshot_a',
                'game_id' => 'gam_snapshot',
                'allocation_percent' => 50,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-snapshot-a',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 2)
            ->json();

        $this->insertVirtualSupplyLayer('gam_snapshot', 'vsl_snapshot_topup', 'snapshot-topup-seed', 4);
        DB::table('stock_supply_profiles')->where('id', 'vsp_gam_snapshot')->update([
            'total_capacity' => 8,
            'updated_at' => now(),
        ]);

        $storedAllocationA = DB::table('partner_stock_allocations')->where('id', $allocationA['id'])->first();
        $this->assertSame(2, (int) $storedAllocationA->allocated_count);
        $this->assertSame(['vsl_snapshot_initial'], json_decode((string) $storedAllocationA->supply_layer_ids_json, true));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/gam_snapshot/numbers/000001', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('generated_capacity', 2)
            ->assertJsonPath('virtual_copies.1.owner.type', 'unassigned')
            ->assertJsonPath('virtual_copies.1.owner.label', 'no_agent');

        $allocationB = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_snapshot_b',
                'tenant_id' => 'ten_snapshot_b',
                'game_id' => 'gam_snapshot',
                'allocation_percent' => 50,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-snapshot-b',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 2)
            ->json();

        $storedAllocationB = DB::table('partner_stock_allocations')->where('id', $allocationB['id'])->first();
        $this->assertSame(['vsl_snapshot_topup'], json_decode((string) $storedAllocationB->supply_layer_ids_json, true));
    }

    public function test_CentralAllocation_create_allows_additional_partner_when_current_layer_still_has_remaining_percent(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_layer_a', 'ten_layer_a');
        $this->insertActivePartnerTenant('par_layer_b', 'ten_layer_b');
        $this->insertGame('gam_layer_remaining', 'open');
        $this->insertVirtualSupplyProfile('gam_layer_remaining', 10);

        $login = $this->createCentralSession(['stock.allocate'], 'adm_layer_remaining', 'layer-remaining@example.test');

        $allocationA = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_layer_a',
                'tenant_id' => 'ten_layer_a',
                'game_id' => 'gam_layer_remaining',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-layer-remaining-a',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 1)
            ->json();

        $allocationB = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_layer_b',
                'tenant_id' => 'ten_layer_b',
                'game_id' => 'gam_layer_remaining',
                'allocation_percent' => 10,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-layer-remaining-b',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 1)
            ->json();

        $storedAllocationA = DB::table('partner_stock_allocations')->where('id', $allocationA['id'])->first();
        $storedAllocationB = DB::table('partner_stock_allocations')->where('id', $allocationB['id'])->first();

        $this->assertSame(['vsp_gam_layer_remaining'], json_decode((string) $storedAllocationA->supply_layer_ids_json, true));
        $this->assertSame(['vsp_gam_layer_remaining'], json_decode((string) $storedAllocationB->supply_layer_ids_json, true));
        $this->assertSame(2000, (int) DB::table('stock_partner_distributions')->where('game_id', 'gam_layer_remaining')->sum('percent_basis_points'));
    }

    private function insertVirtualSupplyProfile(string $gameId, int $capacity): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'allocation-percent-seed',
            'base_count' => $capacity,
            'total_capacity' => $capacity,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertVirtualSupplyLayer(string $gameId, string $layerId, string $seed, int $capacity): void
    {
        DB::table('stock_generation_batches')->insert([
            'id' => 'stb_'.$layerId,
            'game_id' => $gameId,
            'type' => 'virtual_profile',
            'status' => 'completed',
            'requested_count' => $capacity,
            'generated_count' => $capacity,
            'total_rounds' => 0,
            'processed_rounds' => 0,
            'chunk_rounds' => 0,
            'range_start' => '000001',
            'range_end' => '000004',
            'number_digits' => 6,
            'idempotency_key' => $layerId,
            'payload_hash' => hash('sha256', $layerId),
            'created_by_admin_id' => null,
            'payload_json' => json_encode(['layer_id' => $layerId], JSON_THROW_ON_ERROR),
            'started_at' => now(),
            'completed_at' => now(),
            'failed_at' => null,
            'failure_reason' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('virtual_stock_supply_layers')->insert([
            'id' => $layerId,
            'profile_id' => 'vsp_'.$gameId,
            'batch_id' => 'stb_'.$layerId,
            'game_id' => $gameId,
            'status' => 'active',
            'layer_seed' => $seed,
            'base_count' => $capacity,
            'total_capacity' => $capacity,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, string> $numbers
     */
    private function insertBaseLotteryNumbers(array $numbers): void
    {
        $rows = [];

        foreach ($numbers as $number) {
            $rows[] = [
                'full_number' => $number,
                'front3' => substr($number, 0, 3),
                'back3' => substr($number, -3),
                'back2' => substr($number, -2),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        DB::table('base_lottery_numbers')->insert($rows);
    }
}
