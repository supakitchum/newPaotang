<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class CommissionTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Commission_calculation_is_command_driven_idempotent_outboxed_and_reversible(): void
    {
        $world = $this->prepareM8World('commission-main');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-main', 1500);
        $admin = $this->m8TenantAdmin($world, ['commission.view', 'commission.approve'], 'commission-manager');

        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $graph['attribution_id'],
            'status' => 'pending',
        ]);

        Artisan::call('commission:calculate', [
            'order_id' => $world['order_id'],
            '--tenant_id' => $world['tenant_id'],
        ]);

        $commission = DB::table('commission_transactions')
            ->where('tenant_id', $world['tenant_id'])
            ->where('order_id', $world['order_id'])
            ->first();

        $this->assertNotNull($commission);
        $this->assertSame($graph['affiliate_id'], $commission->affiliate_account_id);
        $this->assertSame($graph['rule_id'], $commission->commission_rule_id);
        $this->assertSame(1500, (int) $commission->amount);
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $graph['attribution_id'],
            'status' => 'converted',
            'order_id' => $world['order_id'],
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'commission.calculated.v1',
            'producer' => 'affiliate_commission',
            'aggregate_id' => $commission->id,
        ]);

        Artisan::call('commission:calculate', [
            'order_id' => $world['order_id'],
            '--tenant_id' => $world['tenant_id'],
        ]);

        $this->assertSame(1, DB::table('commission_transactions')->where('order_id', $world['order_id'])->where('transaction_type', 'commission')->count());

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/commission-transactions/'.$commission->id.'/approve', [
                'reason' => 'ready for payout',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'commission-approve-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $reversed = app(GrowthService::class)->reverseCommissionsForOrder($world['order_id']);
        $this->assertSame(1, $reversed);
        $this->assertSame(2, DB::table('commission_transactions')->where('order_id', $world['order_id'])->count());
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $world['order_id'],
            'transaction_type' => 'reversal',
            'original_commission_id' => $commission->id,
            'amount' => -1500,
        ]);
        $this->assertDatabaseHas('commission_transactions', [
            'id' => $commission->id,
            'transaction_type' => 'commission',
        ]);
    }

    public function test_Commission_calculation_ignores_archived_rules(): void
    {
        $world = $this->prepareM8World('commission-archived');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-archived', 900);

        DB::table('commission_rules')->where('id', $graph['rule_id'])->update([
            'status' => 'archived',
            'updated_at' => now(),
        ]);

        $created = app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        $this->assertSame(0, $created);
        $this->assertDatabaseMissing('commission_transactions', [
            'order_id' => $world['order_id'],
        ]);
    }

    public function test_Commission_calculation_skips_expired_and_cancelled_attributions(): void
    {
        foreach (['expired', 'cancelled'] as $status) {
            $world = $this->prepareM8World('commission-'.$status);
            $graph = $this->insertM8AffiliateGraph($world, 'commission-'.$status, 700);

            DB::table('affiliate_attributions')->where('id', $graph['attribution_id'])->update([
                'status' => $status,
                'updated_at' => now(),
            ]);

            $created = app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

            $this->assertSame(0, $created);
            $this->assertDatabaseMissing('commission_transactions', [
                'order_id' => $world['order_id'],
                'affiliate_attribution_id' => $graph['attribution_id'],
            ]);
            $this->assertDatabaseHas('affiliate_attributions', [
                'id' => $graph['attribution_id'],
                'status' => $status,
                'order_id' => null,
            ]);
        }
    }
}
