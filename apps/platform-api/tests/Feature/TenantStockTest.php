<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class TenantStockTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_TenantStock_list_view_export_are_permissioned_tenant_scoped_and_audited(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_stock_tenant', 'ten_stock_tenant', 'tenant-stock.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_stock_other', 'ten_stock_other', 'tenant-stock-other.newpaotang.test');
        $this->insertGame('gam_tenant_stock', 'open');
        $stockIds = $this->syncAllocatedStockToLocal('par_stock_tenant', 'ten_stock_tenant', 'gam_tenant_stock', 2, 'alloc-tenant-stock', 111110);
        $otherStockIds = $this->syncAllocatedStockToLocal('par_stock_other', 'ten_stock_other', 'gam_tenant_stock', 1, 'alloc-other-stock', 222220);

        $limited = $this->createTenantSession('ten_stock_tenant', 'par_stock_tenant', ['stock.sync'], 'adm_stock_limited', 'stock-limited@example.test');
        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/tenant/stock', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $stockAdmin = $this->createTenantSession(
            'ten_stock_tenant',
            'par_stock_tenant',
            ['stock.view', 'stock.export'],
            'adm_stock_view',
            'stock-view@example.test',
        );

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock?game_id=gam_tenant_stock&number=111110', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $stockIds[0])
            ->assertJsonPath('data.0.tenant_id', 'ten_stock_tenant')
            ->assertJsonPath('meta.has_more', false);

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/'.$stockIds[0], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertOk()
            ->assertJsonPath('id', $stockIds[0])
            ->assertJsonPath('full_number', '111110');

        $this->withToken($stockAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/stock/'.$otherStockIds[0], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $export = $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
                'Idempotency-Key' => 'tenant-stock-export',
            ])
            ->assertAccepted()
            ->assertJsonPath('tenant_id', 'ten_stock_tenant')
            ->json();

        $replay = $this->withToken($stockAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/stock/exports', [
                'game_id' => 'gam_tenant_stock',
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_stock_tenant',
                'Idempotency-Key' => 'tenant-stock-export',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($export['id'], $replay['id']);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_stock_tenant',
            'action' => 'stock.export_requested',
            'target_id' => $export['id'],
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('target_id', $export['id'])
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['api_secret']);
    }
}
