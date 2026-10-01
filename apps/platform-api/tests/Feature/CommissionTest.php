<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Commerce\Services\WalletPostingService;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Modules\Growth\Services\AffiliateTierService;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class CommissionTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_commission_batch_isolates_one_order_failure_and_processes_the_next_order(): void
    {
        $failedWorld = $this->prepareM8World('commission-batch-failed');
        $failedGraph = $this->insertM8AffiliateGraph($failedWorld, 'commission-batch-failed', 500);
        $goodWorld = $this->prepareM8World('commission-batch-good');
        $this->insertM8AffiliateGraph($goodWorld, 'commission-batch-good', 700);

        $realService = app(GrowthService::class);
        $service = \Mockery::mock(GrowthService::class, [
            app(AuditLogger::class),
            app(IdempotencyService::class),
            app(CentralTelegramNotificationService::class),
            app(CustomerNotificationDomainEventService::class),
            app(AffiliateTierService::class),
            app(CustomerAuthService::class),
            app(WalletPostingService::class),
        ])->makePartial();
        $service->shouldReceive('bindAffiliateAttributionToPaidOrder')
            ->twice()
            ->andReturnUsing(function (string $orderId, string $tenantId) use ($failedWorld, $realService): ?string {
                if ($orderId === $failedWorld['order_id'] && $tenantId === $failedWorld['tenant_id']) {
                    throw new RuntimeException('synthetic commission failure');
                }

                return $realService->bindAffiliateAttributionToPaidOrder($orderId, $tenantId);
            });
        $result = $service->calculateCommissionsBatch(limit: 10);

        $this->assertSame(2, $result['selected']);
        $this->assertSame(1, $result['succeeded']);
        $this->assertSame(1, $result['failed']);
        $this->assertSame(1, $result['created']);
        $this->assertSame($failedWorld['order_id'], $result['failures'][0]['order_id']);
        $this->assertSame(RuntimeException::class, $result['failures'][0]['exception']);
        $this->assertDatabaseMissing('commission_transactions', [
            'order_id' => $failedWorld['order_id'],
            'transaction_type' => 'commission',
        ]);
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $failedGraph['attribution_id'],
            'status' => 'pending',
        ]);
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $goodWorld['order_id'],
            'transaction_type' => 'commission',
            'amount' => 700,
        ]);
    }

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
        $buyerCustomerNo = $world['customer_no'];
        $receiverCustomerNo = $graph['owner_customer_no'];

        $this->assertNotNull($commission);
        $this->assertSame($graph['affiliate_id'], $commission->affiliate_account_id);
        $this->assertSame($graph['rule_id'], $commission->commission_rule_id);
        $this->assertSame(1500, (int) $commission->amount);
        $this->assertSame('approved', $commission->status);
        $this->assertNotNull($commission->approved_at);
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

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/commission-transactions/'.$commission->id, [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('id', $commission->id)
            ->assertJsonPath('status', 'approved')
            ->assertJsonPath('amount.amount', 1500)
            ->assertJsonPath('receiver_customer.id', $graph['owner_customer_id'])
            ->assertJsonPath('buyer_customer.id', $world['customer_id'])
            ->assertJsonPath('receiver_customer_no', $receiverCustomerNo)
            ->assertJsonPath('buyer_customer_no', $buyerCustomerNo);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/commission-transactions?receiver_customer_no='.$receiverCustomerNo.'&buyer_customer_no='.$buyerCustomerNo.'&sort_by=calculated_at&sort_dir=desc', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $commission->id)
            ->assertJsonPath('data.0.receiver_customer.id', $graph['owner_customer_id'])
            ->assertJsonPath('data.0.buyer_customer.id', $world['customer_id'])
            ->assertJsonPath('data.0.receiver_customer_no', $receiverCustomerNo)
            ->assertJsonPath('data.0.buyer_customer_no', $buyerCustomerNo);

        Artisan::call('commission:calculate', [
            'order_id' => $world['order_id'],
            '--tenant_id' => $world['tenant_id'],
        ]);

        $this->assertSame(1, DB::table('commission_transactions')->where('order_id', $world['order_id'])->where('transaction_type', 'commission')->count());

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/commission-transactions/'.$commission->id.'/approve', [], [
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
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.commission.reversed',
            'action_key' => 'affiliate_commissions',
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

    public function test_delayed_commission_uses_payment_snapshot_after_affiliate_configuration_is_archived(): void
    {
        $world = $this->prepareM8World('commission-payment-snapshot');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-payment-snapshot', 1250);
        $growth = app(GrowthService::class);

        $this->assertSame(
            $graph['attribution_id'],
            $growth->bindAffiliateAttributionToPaidOrder($world['order_id'], $world['tenant_id']),
        );

        DB::table('affiliate_accounts')->where('id', $graph['affiliate_id'])->update(['status' => 'archived']);
        DB::table('affiliate_links')->where('id', $graph['link_id'])->update(['status' => 'archived']);
        DB::table('affiliate_programs')->where('id', $graph['program_id'])->update(['status' => 'archived']);
        DB::table('commission_rules')->where('id', $graph['rule_id'])->update(['status' => 'archived']);

        $this->assertSame(1, $growth->calculateCommissions($world['order_id'], $world['tenant_id']));
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $world['order_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'commission_rule_id' => $graph['rule_id'],
            'amount' => 1250,
        ]);
    }

    public function test_referral_created_after_payment_cannot_claim_an_older_paid_order(): void
    {
        $world = $this->prepareM8World('commission-post-payment-referral');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-post-payment-referral', 800);
        DB::table('orders')->where('id', $world['order_id'])->update([
            'paid_at' => now()->subDay(),
            'created_at' => now()->subDay(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_attributions')->where('id', $graph['attribution_id'])->update([
            'attributed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(
            0,
            app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']),
        );
        $this->assertDatabaseMissing('commission_transactions', [
            'order_id' => $world['order_id'],
            'transaction_type' => 'commission',
        ]);
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $graph['attribution_id'],
            'order_id' => null,
            'status' => 'pending',
        ]);
    }

    public function test_attribution_expiring_after_payment_remains_eligible_for_delayed_commission(): void
    {
        $world = $this->prepareM8World('commission-expired-after-payment');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-expired-after-payment', 650);
        DB::table('orders')->where('id', $world['order_id'])->update([
            'paid_at' => now()->subHour(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_attributions')->where('id', $graph['attribution_id'])->update([
            'attributed_at' => now()->subHours(2),
            'metadata_json' => json_encode([
                'expires_at' => now()->subMinutes(30)->toIso8601String(),
            ], JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);

        $this->assertSame(
            1,
            app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']),
        );
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $world['order_id'],
            'amount' => 650,
        ]);
    }

    public function test_scheduled_commission_scan_skips_old_paid_orders_without_pending_attribution(): void
    {
        $world = $this->prepareM8World('commission-scan-starvation');
        $graph = $this->insertM8AffiliateGraph($world, 'commission-scan-starvation', 550);
        $growth = app(GrowthService::class);
        $growth->bindAffiliateAttributionToPaidOrder($world['order_id'], $world['tenant_id']);

        $oldOrder = (array) DB::table('orders')->where('id', $world['order_id'])->first();
        $oldOrder['id'] = 'ord_commission_scan_old';
        $oldOrder['reference'] = 'M8-commission-scan-old';
        $oldOrder['idempotency_key'] = 'm8-order-commission-scan-old';
        $oldOrder['payload_hash'] = hash('sha256', 'm8-order-commission-scan-old');
        $oldOrder['paid_at'] = now()->subDays(2);
        $oldOrder['created_at'] = now()->subDays(2);
        $oldOrder['updated_at'] = now()->subDays(2);
        DB::table('orders')->insert($oldOrder);

        $this->assertSame(1, $growth->calculateCommissions(null, $world['tenant_id'], 1));
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $world['order_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'amount' => 550,
        ]);
        $this->assertDatabaseMissing('commission_transactions', [
            'order_id' => $oldOrder['id'],
        ]);
    }

    public function test_order_refund_reverses_commission_once_across_different_idempotency_keys(): void
    {
        $world = $this->prepareM8World('commission-refund-reversal');
        $walletId = 'wal_m8_refund_reversal';
        DB::table('wallets')->insert([
            'id' => $walletId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'name' => 'Primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 0,
            'currency' => 'THB',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('orders')->where('id', $world['order_id'])->update([
            'wallet_id' => $walletId,
            'updated_at' => now(),
        ]);
        $graph = $this->insertM8AffiliateGraph($world, 'commission-refund-reversal', 725);
        $growth = app(GrowthService::class);
        $this->assertSame(1, $growth->calculateCommissions($world['order_id'], $world['tenant_id']));
        $manager = $this->m8TenantAdmin($world, ['order.refund'], 'commission-refund-manager');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];
        $payload = [
            'amount' => ['amount' => 10000, 'currency' => 'THB'],
            'reason' => 'Refund paid Affiliate order',
        ];

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$world['order_id'].'/refund', $payload, [
                ...$headers,
                'Idempotency-Key' => 'commission-refund-first',
            ])
            ->assertOk()
            ->assertJsonPath('payment_status', 'refunded');
        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$world['order_id'].'/refund', $payload, [
                ...$headers,
                'Idempotency-Key' => 'commission-refund-second',
            ])
            ->assertOk()
            ->assertJsonPath('payment_status', 'refunded');

        $this->assertSame(1, DB::table('commission_transactions')
            ->where('order_id', $world['order_id'])
            ->where('transaction_type', 'reversal')
            ->count());
        $this->assertDatabaseHas('commission_transactions', [
            'order_id' => $world['order_id'],
            'transaction_type' => 'reversal',
            'original_commission_id' => DB::table('commission_transactions')
                ->where('order_id', $world['order_id'])
                ->where('transaction_type', 'commission')
                ->value('id'),
            'amount' => -725,
        ]);
    }
}
