<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class PartnerSyncAllocationTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_PartnerSync_allocations_returns_virtual_distribution_allocation_data(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_sync_virtual', 'ten_sync_virtual', 'sync-virtual.newpaotang.test');
        $this->insertGame('gam_sync_virtual', 'open');
        $this->insertVirtualSupplyProfile('gam_sync_virtual', 20);
        $this->insertPartnerApiClient('par_sync_virtual', 'partner-sync-token');

        $central = $this->createCentralSession(['stock.allocate'], 'adm_sync_virtual', 'sync-virtual@example.test');
        $allocation = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_sync_virtual',
                'tenant_id' => 'ten_sync_virtual',
                'game_id' => 'gam_sync_virtual',
                'allocation_percent' => 25,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'sync-virtual-allocation',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 5)
            ->json();

        $this->assertSame(0, DB::table('partner_stock_allocation_items')->where('allocation_id', $allocation['id'])->count());

        $this->withToken('partner-sync-token')
            ->getJson('/api/v1/partner-sync/allocations', [
                'X-Partner-Id' => 'par_sync_virtual',
                'X-Tenant-Id' => 'ten_sync_virtual',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.source', 'stock_partner_distributions')
            ->assertJsonPath('data.0.stock_mode', 'virtual')
            ->assertJsonPath('data.0.allocation_id', $allocation['id'])
            ->assertJsonPath('data.0.partner_id', 'par_sync_virtual')
            ->assertJsonPath('data.0.tenant_id', 'ten_sync_virtual')
            ->assertJsonPath('data.0.game_id', 'gam_sync_virtual')
            ->assertJsonPath('data.0.allocation_percent', 25)
            ->assertJsonPath('data.0.allocation_percent_basis_points', 2500)
            ->assertJsonPath('data.0.generated_supply_count', 20)
            ->assertJsonPath('data.0.allocated_count', 5)
            ->assertJsonPath('data.0.remaining_count', 5)
            ->assertJsonPath('meta.has_more', false);
    }

    private function insertVirtualSupplyProfile(string $gameId, int $capacity): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'partner-sync-seed',
            'base_count' => $capacity,
            'total_capacity' => $capacity,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertPartnerApiClient(string $partnerId, string $token): void
    {
        DB::table('partner_api_clients')->insert([
            'id' => 'pac_'.substr(sha1($partnerId.':'.$token), 0, 20),
            'partner_id' => $partnerId,
            'name' => 'Partner Sync Test Client',
            'client_key' => 'client_'.$partnerId,
            'secret_hash' => hash('sha256', $token),
            'status' => 'active',
            'scopes_json' => json_encode(['partner-sync'], JSON_THROW_ON_ERROR),
            'last_used_at' => null,
            'revoked_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
