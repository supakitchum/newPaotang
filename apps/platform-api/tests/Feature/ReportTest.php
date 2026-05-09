<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Report_and_export_jobs_are_scoped_for_tenant_and_central_admins(): void
    {
        $world = $this->prepareM8World('report-main');
        $this->insertM8AffiliateGraph($world, 'report-main', 1200);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        $tenantAdmin = $this->m8TenantAdmin($world, ['report.view'], 'report-tenant');
        $centralAdmin = $this->m8CentralAdmin(['report.view'], 'report-central');
        $tenantHeaders = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];
        $centralHeaders = ['X-Admin-Scope' => 'central'];

        $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/commission', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('summary.commission_total.amount', 1200);

        $tenantExport = $this->withToken($tenantAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/reports/commission/exports', [
                'format' => 'csv',
                'filters' => ['status' => 'calculated'],
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-report-export-main'])
            ->assertAccepted()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('status', 'ready')
            ->json();

        $this->withToken($tenantAdmin['access_token'])
            ->getJson('/api/v1/admin/tenant/export-jobs/'.$tenantExport['id'], $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('id', $tenantExport['id']);

        $this->withToken($tenantAdmin['access_token'])
            ->get('/api/v1/admin/tenant/export-jobs/'.$tenantExport['id'].'/download', $tenantHeaders)
            ->assertStatus(302)
            ->assertHeader('Location', $tenantExport['download_url']);

        $centralExport = $this->withToken($centralAdmin['access_token'])
            ->postJson('/api/v1/admin/central/reports/overview/exports', [
                'format' => 'pdf',
                'tenant_id' => $world['tenant_id'],
            ], $centralHeaders + ['Idempotency-Key' => 'central-report-export-main'])
            ->assertAccepted()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->json();

        $this->withToken($centralAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reports/overview?tenant_id='.$world['tenant_id'], $centralHeaders)
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', $world['tenant_id']);

        $this->withToken($centralAdmin['access_token'])
            ->get('/api/v1/admin/central/export-jobs/'.$centralExport['id'].'/download', $centralHeaders)
            ->assertStatus(302)
            ->assertHeader('Location', $centralExport['download_url']);
    }
}
