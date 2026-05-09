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

        $central = $this->createCentralSession(['stock.allocate'], 'adm_sync_alloc', 'sync-alloc@example.test');
        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_sync',
                'tenant_id' => 'ten_sync',
                'game_id' => 'gam_sync',
                'requested_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'sync-allocation',
                'X-Request-Id' => 'req-sync-allocation',
            ])
            ->assertAccepted();

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
}
