<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class CentralAllocationTest extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_CentralAllocation_create_view_list_recall_allocated_stock_cancel_and_enforce_constraints(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_alloc', 'ten_alloc');
        $this->insertGame('gam_alloc', 'open');
        $this->insertStockItems('gam_alloc', 5);
        $this->insertQuota('pqt_alloc', 'par_alloc', 'gam_alloc', 6);

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
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $allocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 3,
                'reason' => 'initial quota',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-create-main',
                'X-Request-Id' => 'req-allocation-create',
            ])
            ->assertAccepted()
            ->assertJsonPath('partner_id', 'par_alloc')
            ->assertJsonPath('tenant_id', 'ten_alloc')
            ->assertJsonPath('game_id', 'gam_alloc')
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('allocated_count', 3)
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
        $this->assertSame(3, DB::table('stock_items')->where('allocation_id', $allocation['id'])->where('status', 'allocated')->count());
        $this->assertDatabaseHas('partner_quotas', [
            'id' => 'pqt_alloc',
            'allocated_count' => 3,
        ]);

        $sameAllocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 3,
                'reason' => 'initial quota',
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
                'requested_count' => 3,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-create-no-stock',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocations/'.$allocation['id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $allocation['id']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocations?partner_id=par_alloc&tenant_id=ten_alloc&game_id=gam_alloc', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $allocation['id']);

        $recallLogin = $this->createCentralSession(['stock.recall'], 'adm_recall_alloc', 'recall-alloc@example.test');
        $allocatedStockId = (string) DB::table('stock_items')
            ->where('allocation_id', $allocation['id'])
            ->orderBy('full_number')
            ->value('id');

        $this->withToken($recallLogin['access_token'])
            ->postJson('/api/v1/admin/central/stock/'.$allocatedStockId.'/recall', [
                'reason' => 'quota_adjustment',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-stock-recall',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'recalled');

        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.recalled.v1',
            'aggregate_id' => $allocatedStockId,
            'partner_id' => 'par_alloc',
            'tenant_id' => 'ten_alloc',
        ]);
        $this->assertDatabaseHas('partner_stock_allocations', [
            'id' => $allocation['id'],
            'status' => 'partially_allocated',
            'allocated_count' => 2,
        ]);
        $this->assertDatabaseHas('partner_quotas', [
            'id' => 'pqt_alloc',
            'allocated_count' => 2,
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations/'.$allocation['id'].'/cancel', [
                'reason' => 'sync cancelled before partner pull',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-cancel-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled')
            ->assertJsonPath('allocated_count', 0);

        $this->assertSame(4, DB::table('stock_items')->where('game_id', 'gam_alloc')->where('status', 'available')->count());
        $this->assertSame(1, DB::table('stock_items')->where('game_id', 'gam_alloc')->where('status', 'recalled')->count());
        $this->assertDatabaseHas('partner_quotas', [
            'id' => 'pqt_alloc',
            'allocated_count' => 0,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'stock.allocation_cancelled',
            'target_id' => $allocation['id'],
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 7,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-over-quota',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.requested_count.0', 'The requested_count exceeds the active partner quota.');

        DB::table('games')->where('id', 'gam_alloc')->update(['status' => 'closed', 'updated_at' => now()]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-closed-game',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference an open game.');

        DB::table('games')->where('id', 'gam_alloc')->update(['status' => 'open', 'updated_at' => now()]);
        DB::table('partner_tenants')->where('id', 'ten_alloc')->update(['status' => 'suspended', 'updated_at' => now()]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_alloc',
                'tenant_id' => 'ten_alloc',
                'game_id' => 'gam_alloc',
                'requested_count' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-suspended-tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.tenant_id.0', 'The tenant_id field must reference an active tenant for an active partner.');
    }

    public function test_CentralAllocation_percent_workflow_options_recall_all_redistribute_and_validation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_percent_a', 'ten_percent_a');
        $this->insertActivePartnerTenant('par_percent_b', 'ten_percent_b');
        $this->insertGame('gam_percent', 'open');
        $this->insertVirtualSupplyProfile('gam_percent', 10);

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
            ->assertJsonPath('data.0.active_tenant_count', 1);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/allocation-options/tenants?partner_id=par_percent_a', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.tenant_id', 'ten_percent_a')
            ->assertJsonPath('data.0.partner_id', 'par_percent_a');

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
            ->assertJsonPath('target_allocation_count', 7);

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

    public function test_CentralAllocation_same_key_replay_returns_existing_allocation_after_quota_is_exhausted(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_replay', 'ten_replay');
        $this->insertGame('gam_replay', 'open');
        $this->insertStockItems('gam_replay', 2);
        $this->insertQuota('pqt_replay', 'par_replay', 'gam_replay', 2);
        $login = $this->createCentralSession(['stock.allocate'], 'adm_replay', 'replay@example.test');

        $allocation = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_replay',
                'tenant_id' => 'ten_replay',
                'game_id' => 'gam_replay',
                'requested_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-replay-exhausts-quota',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 2)
            ->json();

        $stockStateBeforeReplay = DB::table('stock_items')
            ->where('game_id', 'gam_replay')
            ->orderBy('id')
            ->get(['id', 'status', 'partner_id', 'tenant_id', 'allocation_id'])
            ->map(fn (object $row): array => (array) $row)
            ->all();

        $replay = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_replay',
                'tenant_id' => 'ten_replay',
                'game_id' => 'gam_replay',
                'requested_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-replay-exhausts-quota',
            ])
            ->assertAccepted()
            ->assertJsonPath('id', $allocation['id'])
            ->assertJsonPath('allocated_count', 2)
            ->json();

        $this->assertSame($allocation['id'], $replay['id']);
        $this->assertSame(1, DB::table('partner_stock_allocations')->where('game_id', 'gam_replay')->count());
        $this->assertSame(2, DB::table('partner_stock_allocation_items')->where('allocation_id', $allocation['id'])->count());
        $this->assertSame(1, DB::table('sync_outbox')->where('event_type', 'stock.allocated.v1')->where('aggregate_id', $allocation['id'])->count());
        $this->assertSame(2, DB::table('partner_quotas')->where('id', 'pqt_replay')->value('allocated_count'));
        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_replay')->where('status', 'allocated')->count());

        $stockStateAfterReplay = DB::table('stock_items')
            ->where('game_id', 'gam_replay')
            ->orderBy('id')
            ->get(['id', 'status', 'partner_id', 'tenant_id', 'allocation_id'])
            ->map(fn (object $row): array => (array) $row)
            ->all();

        $this->assertSame($stockStateBeforeReplay, $stockStateAfterReplay);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_replay',
                'tenant_id' => 'ten_replay',
                'game_id' => 'gam_replay',
                'requested_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'allocation-replay-different-key',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.requested_count.0', 'The requested_count exceeds the active partner quota.');
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
}
