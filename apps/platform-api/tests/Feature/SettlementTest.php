<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class SettlementTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Settlement_list_detail_and_approval_are_central_only_and_idempotent(): void
    {
        $world = $this->prepareM8World('settlement-main');
        $graph = $this->insertM8AffiliateGraph($world, 'settlement-main', 1100);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_settlement_main',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'approved',
            'payout_method' => 'manual_cash',
            'amount' => 300,
            'currency' => 'THB',
            'bank_account_json' => null,
            'admin_note' => null,
            'idempotency_key' => null,
            'payload_hash' => null,
            'requested_by_admin_id' => null,
            'approved_by_admin_id' => null,
            'approved_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $viewer = $this->m8CentralAdmin(['settlement.view'], 'settlement-viewer');
        $approver = $this->m8CentralAdmin(['settlement.view', 'settlement.approve'], 'settlement-approver');
        $headers = ['X-Admin-Scope' => 'central'];

        $list = $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/central/settlements?partner_id='.$world['partner_id'], $headers)
            ->assertOk()
            ->assertJsonPath('data.0.partner_id', $world['partner_id'])
            ->assertJsonPath('data.0.tenant_id', $world['tenant_id'])
            ->json();

        $settlementId = $list['data'][0]['id'];

        $this->withToken($viewer['access_token'])
            ->postJson('/api/v1/admin/central/settlements/'.$settlementId.'/approve', [
                'reason' => 'viewer cannot approve',
            ], $headers + ['Idempotency-Key' => 'settlement-denied-main'])
            ->assertForbidden();

        $this->withToken($approver['access_token'])
            ->getJson('/api/v1/admin/central/settlements/'.$settlementId, $headers)
            ->assertOk()
            ->assertJsonPath('id', $settlementId)
            ->assertJsonPath('commission_amount.amount', 1100)
            ->assertJsonPath('payout_amount.amount', 300);

        $this->withToken($approver['access_token'])
            ->postJson('/api/v1/admin/central/settlements/'.$settlementId.'/approve', [
                'reason' => 'ready to settle',
            ], $headers + ['Idempotency-Key' => 'settlement-approve-main', 'X-Request-Id' => 'req-settlement-main'])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->withToken($approver['access_token'])
            ->postJson('/api/v1/admin/central/settlements/'.$settlementId.'/approve', [
                'reason' => 'ready to settle',
            ], $headers + ['Idempotency-Key' => 'settlement-approve-main'])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'settlement.approved',
            'target_id' => $settlementId,
            'tenant_id' => $world['tenant_id'],
        ]);
    }
}
