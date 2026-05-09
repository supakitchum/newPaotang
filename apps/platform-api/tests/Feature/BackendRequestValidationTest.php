<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class BackendRequestValidationTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_Validation_rejects_report_export_payload_before_idempotency_success_storage(): void
    {
        $world = $this->prepareReservedCart('par_val_report', 'ten_val_report', 'validation-report.m5.test', 'gam_val_report', '0809100001', 810001);
        $admin = $this->tenantAdmin($world, ['report.view'], 'valreport');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/reports/commission/exports', [
                'format' => 'xml',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'validation-report-export',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.format.0', 'The format field must be one of csv, xlsx, or pdf.');

        $this->assertDatabaseMissing('idempotency_keys', [
            'tenant_id' => $world['tenant_id'],
            'route_key' => 'admin.tenant.reports.exports:commission',
            'idempotency_key' => 'validation-report-export',
        ]);
        $this->assertSame(0, DB::table('report_export_jobs')->where('tenant_id', $world['tenant_id'])->count());
    }

    public function test_Validation_rejects_report_query_scope_controls(): void
    {
        $this->seedDefaultRbac();
        $admin = $this->createCentralSession(['report.view'], 'adm_val_report_query', 'val-report-query@example.test');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/reports/overview?date_from=2026-05-10&date_to=2026-05-01&limit=1000', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.limit.0', 'The limit field must not be greater than 100.')
            ->assertJsonPath('error.details.fields.date_to.0', 'The date_to field must be after or equal to date_from.');
    }

    public function test_Validation_rejects_wallet_adjustment_before_ledger_and_idempotency_mutation(): void
    {
        $world = $this->prepareReservedCart('par_val_wallet', 'ten_val_wallet', 'validation-wallet.m5.test', 'gam_val_wallet', '0809100002', 820001);
        $admin = $this->tenantAdmin($world, ['wallet.view', 'wallet.adjust'], 'valwallet');

        $response = $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'amount' => ['amount' => 0, 'currency' => 'THB'],
                'reason' => 'invalid zero adjustment',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'validation-wallet-adjust',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->assertSame(
            'The amount.amount field must be greater than zero.',
            $response->json('error.details.fields')['amount.amount'][0] ?? null,
        );

        $this->assertDatabaseMissing('idempotency_keys', [
            'tenant_id' => $world['tenant_id'],
            'route_key' => 'admin.tenant.wallets.adjust:'.$world['wallet_id'],
            'idempotency_key' => 'validation-wallet-adjust',
        ]);
        $this->assertDatabaseMissing('wallet_ledger', [
            'tenant_id' => $world['tenant_id'],
            'wallet_id' => $world['wallet_id'],
            'idempotency_key' => 'validation-wallet-adjust',
        ]);
    }
}
