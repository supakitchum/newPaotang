<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class RetiredTenantStockSyncTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_TenantStockSync_routes_are_retired_from_partner_back_office(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_sync_retired', 'ten_sync_retired', 'sync-retired.newpaotang.test');

        $admin = $this->createTenantSession(
            'ten_sync_retired',
            'par_sync_retired',
            ['stock.view'],
            'adm_sync_retired',
            'sync-retired@example.test',
        );

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock-sync/batches', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync_retired',
            ])
            ->assertNotFound();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sync_retired',
                'Idempotency-Key' => 'retired-stock-sync',
            ])
            ->assertNotFound();
    }
}
