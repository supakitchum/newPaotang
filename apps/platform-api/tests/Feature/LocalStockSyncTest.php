<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class LocalStockSyncTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_LocalStockSync_consumes_allocation_outbox_dedupes_inbox_and_exposes_batches(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_sync', 'ten_sync', 'sync.newpaotang.test');
        $this->insertGame('gam_sync', 'open');
        $this->insertQuota('pqt_sync', 'par_sync', 'gam_sync', 5);
        $this->insertStockItems('gam_sync', 2);

        $this->insertLegacyAllocatedOutboxForSync('alc_sync', 'par_sync', 'ten_sync', 'gam_sync');

        $limited = $this->createTenantSession('ten_sync', 'par_sync', ['stock.view'], 'adm_sync_limited', 'sync-limited@example.test');
        $this->withToken($limited['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
                'Idempotency-Key' => 'sync-denied',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $sync = $this->createTenantSession('ten_sync', 'par_sync', ['stock.sync'], 'adm_sync', 'sync@example.test');
        $this->withToken($sync['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $batch = $this->withToken($sync['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
                'Idempotency-Key' => 'sync-main',
                'X-Request-Id' => 'req-sync-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('tenant_id', 'ten_sync')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('processed_count', 2)
            ->json();

        $this->assertSame(2, DB::table('local_stock_items')->where('tenant_id', 'ten_sync')->count());
        $this->assertDatabaseHas('local_stock_items', [
            'tenant_id' => 'ten_sync',
            'game_id' => 'gam_sync',
            'store_id' => 'ten_sync',
        ]);
        $this->assertDatabaseHas('sync_inbox', [
            'event_type' => 'stock.allocated.v1',
            'tenant_id' => 'ten_sync',
            'consumer' => 'partner_store',
            'status' => 'processed',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.allocated.v1',
            'tenant_id' => 'ten_sync',
            'status' => 'processed',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.sync_completed.v1',
            'tenant_id' => 'ten_sync',
            'aggregate_id' => $batch['id'],
            'correlation_id' => 'req-sync-main',
        ]);

        $replay = $this->withToken($sync['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
                'Idempotency-Key' => 'sync-main',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($batch['id'], $replay['id']);
        $this->assertSame(2, DB::table('local_stock_items')->where('tenant_id', 'ten_sync')->count());
        $this->assertSame(1, DB::table('sync_inbox')->where('event_type', 'stock.allocated.v1')->count());

        $this->withToken($sync['access_token'])
            ->getJson('/api/v1/admin/tenant/stock-sync/batches', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $batch['id']);

        $this->withToken($sync['access_token'])
            ->getJson('/api/v1/admin/tenant/stock-sync/batches/'.$batch['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync',
            ])
            ->assertOk()
            ->assertJsonPath('id', $batch['id']);
    }

    private function insertLegacyAllocatedOutboxForSync(string $allocationId, string $partnerId, string $tenantId, string $gameId): void
    {
        $now = now();
        $stockRows = DB::table('stock_items')->where('game_id', $gameId)->orderBy('full_number')->get(['id'])->all();

        DB::table('partner_stock_allocations')->insert([
            'id' => $allocationId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => count($stockRows),
            'allocation_percent_basis_points' => null,
            'allocated_count' => count($stockRows),
            'recalled_count' => 0,
            'idempotency_key' => 'sync-allocation',
            'payload_hash' => hash('sha256', 'legacy-sync-fixture'),
            'created_by_admin_id' => null,
            'reason' => 'legacy sync fixture',
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('stock_items')->whereIn('id', array_map(fn (object $row): string => (string) $row->id, $stockRows))->update([
            'status' => 'allocated',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => $allocationId,
            'updated_at' => $now,
        ]);

        DB::table('partner_stock_allocation_items')->insert(array_map(fn (object $row): array => [
            'allocation_id' => $allocationId,
            'stock_item_id' => (string) $row->id,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'status' => 'allocated',
            'created_at' => $now,
            'updated_at' => $now,
        ], $stockRows));

        DB::table('sync_outbox')->insert([
            'id' => 'out_sync_alloc',
            'event_id' => 'evt_sync_alloc',
            'event_type' => 'stock.allocated.v1',
            'event_version' => 1,
            'producer' => 'central_stock',
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'game_id' => $gameId,
            'aggregate_type' => 'partner_stock_allocation',
            'aggregate_id' => $allocationId,
            'idempotency_key' => 'sync-allocation',
            'correlation_id' => 'req-sync-allocation',
            'payload_json' => json_encode([
                'allocation_id' => $allocationId,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'cursor' => $allocationId,
                'item_count' => count($stockRows),
                'chunk_size' => 5000,
            ], JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }
}
