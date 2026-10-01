<?php

namespace Tests\Feature;

use App\Modules\Reward\Events\RewardClaimUpdated;
use App\Modules\Reward\Services\TenantRewardPriceRuleService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\Support\M7RewardFixtures;
use Tests\TestCase;

class RewardClaimTest extends TestCase
{
    use M7RewardFixtures;
    use RefreshDatabase;

    public function test_RewardClaim_updated_event_broadcasts_to_admin_and_customer_channels(): void
    {
        $event = new RewardClaimUpdated([
            'tenant_id' => 'ten_reward_rt',
            'customer_id' => 'cus_reward_rt',
            'claim_id' => 'rcl_reward_rt',
        ]);

        $this->assertSame([
            'private-admin.tenant.ten_reward_rt.reward-claims',
            'private-customer.tenant.ten_reward_rt.customer.cus_reward_rt.reward-claims',
        ], array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn()));
    }

    public function test_RewardClaim_auto_claims_are_created_on_publish_for_wallet_and_bank_settings(): void
    {
        $walletWorld = $this->prepareRewardWorld('par_auto_wallet', 'ten_auto_wallet', 'auto-wallet.m7.test', 'gam_auto_wallet', '0807201100', 791101);

        $this->withToken($walletWorld['auth']['token'])
            ->patchJson('http://'.$walletWorld['host'].'/api/v1/customer/profile', [
                'auto_reward_claim' => [
                    'enabled' => true,
                    'type' => 'wallet',
                ],
            ], [
                'Idempotency-Key' => 'auto-reward-wallet-profile',
            ])
            ->assertOk()
            ->assertJsonPath('auto_reward_claim.enabled', true)
            ->assertJsonPath('auto_reward_claim.payout_method', 'wallet_credit')
            ->assertJsonPath('auto_reward_claim.type', 'wallet');

        $this->publishReward($walletWorld, keySuffix: 'auto-wallet');

        $walletClaim = DB::table('reward_claims')
            ->where('tenant_id', $walletWorld['tenant_id'])
            ->where('ticket_id', $walletWorld['ticket_id'])
            ->first();

        $this->assertNotNull($walletClaim);
        $this->assertSame('submitted', $walletClaim->status);
        $this->assertSame('wallet_credit', $walletClaim->payout_method);
        $this->assertSame($walletWorld['wallet_id'], $walletClaim->wallet_id);
        $this->assertSame(600000000, (int) $walletClaim->prize_amount);

        $this->withToken($walletWorld['auth']['token'])
            ->getJson('http://'.$walletWorld['host'].'/api/v1/customer/tickets/'.$walletWorld['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'claim_submitted')
            ->assertJsonPath('claim_status', 'submitted')
            ->assertJsonPath('reward_claim_id', $walletClaim->id);

        $tenantViewer = $this->tenantAdmin($walletWorld, ['reward_claim.view'], 'auto-wallet-view');
        $this->withToken($tenantViewer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-claims?section=pending', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $walletWorld['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('meta.pending_count', 1)
            ->assertJsonPath('data.0.id', $walletClaim->id);

        $bankWorld = $this->prepareRewardWorld('par_auto_bank', 'ten_auto_bank', 'auto-bank.m7.test', 'gam_auto_bank', '0807201200', 791201);

        $this->withToken($bankWorld['auth']['token'])
            ->patchJson('http://'.$bankWorld['host'].'/api/v1/customer/profile', [
                'reward_payout_bank_account' => [
                    'bank_name' => 'ธนาคารกรุงไทย',
                    'account_name' => 'M5 Customer',
                    'account_number' => '006123456789',
                ],
                'auto_reward_claim' => [
                    'enabled' => true,
                    'type' => 'bank_transfer',
                ],
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'auto-reward-bank-profile',
            ])
            ->assertOk()
            ->assertJsonPath('auto_reward_claim.enabled', true)
            ->assertJsonPath('auto_reward_claim.payout_method', 'bank_transfer');

        $this->publishReward($bankWorld, keySuffix: 'auto-bank');

        $bankClaim = DB::table('reward_claims')
            ->where('tenant_id', $bankWorld['tenant_id'])
            ->where('ticket_id', $bankWorld['ticket_id'])
            ->first();

        $this->assertNotNull($bankClaim);
        $this->assertSame('submitted', $bankClaim->status);
        $this->assertSame('bank_transfer', $bankClaim->payout_method);
        $this->assertNull($bankClaim->wallet_id);
        $this->assertStringContainsString('006123456789', (string) $bankClaim->bank_account_json);
    }

    public function test_RewardClaim_customer_status_claim_and_tenant_approve_pay_are_scoped_idempotent_and_ledger_based(): void
    {
        $world = $this->prepareRewardWorld('par_reward_claim', 'ten_reward_claim', 'reward-claim.m7.test', 'gam_reward_claim', '0807200000', 790201);
        $this->publishReward($world, keySuffix: 'claim');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'winning')
            ->assertJsonPath('claimable', true)
            ->assertJsonPath('prize_amount.amount', 600000000);

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '000000',
                'note' => 'wrong pin must not create a claim',
            ], [
                'Idempotency-Key' => 'reward-claim-wrong-pin',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'pin_invalid');

        $this->assertSame(0, DB::table('reward_claims')->where('tenant_id', $world['tenant_id'])->count());

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
                'note' => 'please credit wallet',
            ], [
                'Idempotency-Key' => 'reward-claim-create',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'submitted')
            ->json();
        $this->assertTrue(CarbonImmutable::parse((string) $claim['submitted_at'])->lessThanOrEqualTo(now()->addMinute()));
        $this->assertTrue(DB::table('reward_claims')->where('id', $claim['id'])->where('submitted_at', '<=', now()->addMinute())->exists());

        $replay = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
                'note' => 'please credit wallet',
            ], [
                'Idempotency-Key' => 'reward-claim-create',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame($claim['id'], $replay['id']);
        $this->assertSame(1, DB::table('reward_claims')->where('tenant_id', $world['tenant_id'])->count());

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'claim_submitted')
            ->assertJsonPath('claimable', false);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/reward-claims')
            ->assertOk()
            ->assertJsonPath('data.0.id', $claim['id']);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/reward-claims/'.$claim['id'])
            ->assertOk()
            ->assertJsonPath('id', $claim['id']);

        $tenantViewer = $this->tenantAdmin($world, ['reward_claim.view'], 'rewardclaimview');
        $tenantPayer = $this->tenantAdmin($world, ['reward_claim.view', 'reward_claim.approve', 'reward_claim.pay'], 'rewardclaimpay');

        $this->withToken($tenantViewer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'permission check',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-claim-approve-denied',
            ])
            ->assertForbidden();

        $this->withToken($tenantPayer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-claims', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('meta.pending_count', 1)
            ->assertJsonPath('data.0.id', $claim['id']);

        $approved = $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'verified ticket owner',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-claim-approve',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved')
            ->json();

        $this->assertSame($claim['id'], $approved['id']);
        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => $world['tenant_id'],
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'credit',
            'amount' => 600000000,
            'reference_type' => 'reward_claim',
            'reference_id' => $claim['id'],
        ]);
        $this->assertDatabaseHas('tickets', [
            'id' => $world['ticket_id'],
            'status' => 'paid_out',
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'paid_out')
            ->assertJsonPath('claim_status', 'approved')
            ->assertJsonPath('reward_claim_id', $claim['id']);

        $claimList = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/reward-claims')
            ->assertOk()
            ->assertJsonPath('data.0.id', $claim['id'])
            ->assertJsonPath('data.0.status', 'approved')
            ->json();
        $this->assertNotNull($claimList['data'][0]['paid_at'] ?? null);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['ticket_id'])
            ->assertJsonPath('data.0.status', 'paid_out')
            ->assertJsonPath('data.0.reward_status.status', 'paid_out')
            ->assertJsonPath('data.0.reward_status.claim_status', 'approved');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/history')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $paid = $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/pay', [
                'payout_method' => 'wallet_credit',
                'reason' => 'credit approved prize',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-claim-pay',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->json();

        $this->assertSame('wallet_credit', $paid['payout_method']);
        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => $world['tenant_id'],
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'credit',
            'amount' => 600000000,
            'reference_type' => 'reward_claim',
            'reference_id' => $claim['id'],
        ]);
        $this->assertDatabaseHas('tickets', [
            'id' => $world['ticket_id'],
            'status' => 'paid_out',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'reward_claim.paid',
            'target_id' => $claim['id'],
            'tenant_id' => $world['tenant_id'],
        ]);
    }

    public function test_RewardClaim_customer_status_and_claim_sum_multiple_prizes_for_one_ticket(): void
    {
        $world = $this->prepareRewardWorld('par_reward_multi', 'ten_reward_multi', 'reward-multi.m7.test', 'gam_reward_multi', '0807200100', 790251);
        $admin = $this->centralRewardAdmin([
            'reward.view',
            'reward.create',
            'reward.verify',
            'reward.publish',
            'reward.correct',
            'reward.audit',
        ], 'reward-multi-prize');
        $ticketNumber = (string) $world['ticket_number'];
        $prizes = $this->thaiGovernmentLotteryPrizes($ticketNumber, $ticketNumber);
        $patchedBack3 = false;
        $patchedBack2 = false;

        foreach ($prizes as &$prize) {
            if (! $patchedBack3 && $prize['prize_type'] === 'back3') {
                $prize['prize_number'] = substr($ticketNumber, -3);
                $patchedBack3 = true;
                continue;
            }

            if (! $patchedBack2 && $prize['prize_type'] === 'back2') {
                $prize['prize_number'] = substr($ticketNumber, -2);
                $patchedBack2 = true;
            }
        }
        unset($prize);

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-multi-prize',
            ])
            ->assertAccepted()
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/verify', [
                'reason' => 'multi prize summary checked',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-verify-multi-prize',
            ])
            ->assertOk();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/publish', [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-publish-multi-prize',
            ])
            ->assertOk();

        $this->assertSame(3, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'winning')
            ->assertJsonPath('claimable', true)
            ->assertJsonPath('prize_count', 3)
            ->assertJsonPath('prize_amount.amount', 600600000)
            ->assertJsonPath('prizes.0.prize_type', 'first_prize')
            ->assertJsonPath('prizes.1.prize_type', 'back3')
            ->assertJsonPath('prizes.2.prize_type', 'back2');

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'reward-claim-create-multi-prize',
            ])
            ->assertCreated()
            ->assertJsonPath('prize_count', 3)
            ->assertJsonPath('prize_amount.amount', 600600000)
            ->json();

        $this->assertSame(1, DB::table('reward_claims')->where('tenant_id', $world['tenant_id'])->count());

        $tenantPayer = $this->tenantAdmin($world, ['reward_claim.view', 'reward_claim.approve'], 'reward-multi-prize-pay');
        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'approve all prize rows for one ticket',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-claim-approve-multi-prize',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => $world['tenant_id'],
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'credit',
            'amount' => 600600000,
            'reference_type' => 'reward_claim',
            'reference_id' => $claim['id'],
        ]);
        $this->assertSame(3, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->where('status', 'paid')->count());
    }

    public function test_RewardClaim_uses_tenant_reward_price_adjustment_snapshot_for_reports(): void
    {
        $world = $this->prepareRewardWorld('par_reward_adjust', 'ten_reward_adjust', 'reward-adjust.m7.test', 'gam_reward_adjust', '0807201000', 790301);

        DB::table('tenant_price_rules')->insert([
            'id' => 'prr_reward_adjust',
            'tenant_id' => $world['tenant_id'],
            'game_id' => $world['game_id'],
            'code' => 'first_prize_minus_1000',
            'name' => 'First prize minus 1000 THB',
            'rule_type' => TenantRewardPriceRuleService::RULE_TYPE_AMOUNT_DELTA,
            'base_source' => TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD,
            'price_amount' => 100000,
            'adjustment_amount' => -100000,
            'adjustment_bps' => null,
            'currency' => 'THB',
            'status' => 'active',
            'conditions_json' => json_encode(['prize_type' => 'first_prize'], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->publishReward($world, keySuffix: 'adjusted');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'winning')
            ->assertJsonPath('prize_amount.amount', 599900000);

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'bank_transfer',
                'pin' => '246810',
                'bank_account' => ['bank' => 'test', 'account_no' => '1234567890'],
            ], [
                'Idempotency-Key' => 'reward-adjust-claim-create',
            ])
            ->assertCreated()
            ->assertJsonPath('prize_amount.amount', 599900000)
            ->assertJsonPath('reward_pricing.base_prize_amount.amount', 600000000)
            ->assertJsonPath('reward_pricing.adjustment_amount.amount', -100000)
            ->assertJsonPath('reward_pricing.tenant_price_rule_id', 'prr_reward_adjust')
            ->assertJsonPath('reward_pricing.price_rule_snapshot.code', 'first_prize_minus_1000')
            ->json();

        $this->assertDatabaseHas('winning_tickets', [
            'tenant_id' => $world['tenant_id'],
            'ticket_id' => $world['ticket_id'],
            'amount' => 599900000,
            'base_amount' => 600000000,
            'adjustment_amount' => -100000,
            'tenant_price_rule_id' => 'prr_reward_adjust',
        ]);
        $this->assertDatabaseHas('reward_claims', [
            'id' => $claim['id'],
            'tenant_id' => $world['tenant_id'],
            'prize_amount' => 599900000,
            'base_prize_amount' => 600000000,
            'adjustment_amount' => -100000,
            'tenant_price_rule_id' => 'prr_reward_adjust',
        ]);

        $tenantReporter = $this->tenantAdmin($world, ['report.view'], 'reward-adjust-report');
        $this->withToken($tenantReporter['access_token'])
            ->getJson('/api/v1/admin/tenant/reports/rewards', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('summary.reward_claims_count', 1)
            ->assertJsonPath('summary.reward_base_total.amount', 600000000)
            ->assertJsonPath('summary.reward_adjustment_total.amount', -100000)
            ->assertJsonPath('summary.reward_payout_total.amount', 599900000)
            ->assertJsonPath('rows.0.base_prize_amount.amount', 600000000)
            ->assertJsonPath('rows.0.adjustment_amount.amount', -100000)
            ->assertJsonPath('rows.0.prize_amount.amount', 599900000);
    }

    public function test_RewardClaim_tenant_exchange_reward_uses_winning_ticket_amount_when_claim_snapshot_is_stale(): void
    {
        $world = $this->prepareRewardWorld('par_reward_stale', 'ten_reward_stale', 'reward-stale.m7.test', 'gam_reward_stale', '0807201300', 791301);
        $this->publishReward($world, keySuffix: 'stale-claim-amount');

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'reward-claim-stale-create',
            ])
            ->assertCreated()
            ->assertJsonPath('prize_amount.amount', 600000000)
            ->json();

        DB::table('reward_claims')->where('id', $claim['id'])->update([
            'prize_amount' => 123,
            'base_prize_amount' => 123,
            'adjustment_amount' => 0,
            'updated_at' => now(),
        ]);

        $tenantPayer = $this->tenantAdmin($world, ['reward_claim.view', 'reward_claim.approve'], 'reward-stale-claim-pay');

        $this->withToken($tenantPayer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-claims?section=pending&customer_id='.$claim['customer']['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $claim['id'])
            ->assertJsonPath('data.0.prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.reward_pricing.base_prize_amount.amount', 600000000);

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'approve corrected winning ticket amount',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-claim-stale-approve',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved')
            ->assertJsonPath('prize_amount.amount', 600000000);

        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => $world['tenant_id'],
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'credit',
            'amount' => 600000000,
            'reference_type' => 'reward_claim',
            'reference_id' => $claim['id'],
        ]);
        $this->assertDatabaseHas('reward_claims', [
            'id' => $claim['id'],
            'prize_amount' => 600000000,
        ]);
    }

    public function test_RewardClaim_approve_bank_transfer_marks_paid_out_without_wallet_credit(): void
    {
        $fixture = $this->submittedRewardClaim('bank_approve', 'bank_transfer');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantApprover = $fixture['admin'];
        $walletBalance = DB::table('wallets')->where('id', $world['wallet_id'])->value('balance_amount');
        $ledgerCount = DB::table('wallet_ledger')
            ->where('tenant_id', $world['tenant_id'])
            ->where('reference_type', 'reward_claim')
            ->where('reference_id', $claim['id'])
            ->count();

        $approved = $this->withToken($tenantApprover['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'approved for bank transfer',
            ], $this->tenantClaimHeaders($world, 'reward-bank-transfer-approve'))
            ->assertOk()
            ->assertJsonPath('status', 'approved')
            ->assertJsonPath('payout_method', 'bank_transfer')
            ->json();

        $this->assertSame($claim['id'], $approved['id']);
        $this->assertSame($walletBalance, DB::table('wallets')->where('id', $world['wallet_id'])->value('balance_amount'));
        $this->assertSame($ledgerCount, DB::table('wallet_ledger')
            ->where('tenant_id', $world['tenant_id'])
            ->where('reference_type', 'reward_claim')
            ->where('reference_id', $claim['id'])
            ->count());
        $this->assertDatabaseHas('reward_claims', [
            'id' => $claim['id'],
            'status' => 'approved',
            'payout_method' => 'bank_transfer',
            'payout_ledger_id' => null,
        ]);
        $this->assertNotNull(DB::table('reward_claims')->where('id', $claim['id'])->value('paid_at'));
        $this->assertDatabaseHas('winning_tickets', [
            'id' => $claim['winning_ticket_id'],
            'status' => 'paid',
        ]);
        $this->assertDatabaseHas('tickets', [
            'id' => $world['ticket_id'],
            'status' => 'paid_out',
        ]);

        $rewardStatus = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'paid_out')
            ->assertJsonPath('claim_status', 'approved')
            ->assertJsonPath('reward_claim_id', $claim['id'])
            ->json();
        $this->assertNotNull($rewardStatus['paid_at'] ?? null);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['ticket_id'])
            ->assertJsonPath('data.0.status', 'paid_out')
            ->assertJsonPath('data.0.reward_status.status', 'paid_out')
            ->assertJsonPath('data.0.reward_status.claim_status', 'approved');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/history')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_RewardClaim_rejected_status_is_visible_to_customer_tickets(): void
    {
        $fixture = $this->submittedRewardClaim('reject_visible');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantPayer = $fixture['admin'];

        Event::fake([RewardClaimUpdated::class]);

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/reject', [
                'reason' => 'customer bank mismatch',
            ], $this->tenantClaimHeaders($world, 'reward-reject-visible'))
            ->assertOk()
            ->assertJsonPath('status', 'rejected');

        Event::assertDispatched(RewardClaimUpdated::class, fn (RewardClaimUpdated $event): bool => (
            ($event->payload['tenant_id'] ?? null) === $world['tenant_id']
            && ($event->payload['claim_id'] ?? null) === $claim['id']
            && ($event->payload['claim']['status'] ?? null) === 'rejected'
        ));

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'rejected')
            ->assertJsonPath('claim_status', 'rejected')
            ->assertJsonPath('claimable', true)
            ->assertJsonPath('reward_claim_id', $claim['id']);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['ticket_id'])
            ->assertJsonPath('data.0.status', 'winning')
            ->assertJsonPath('data.0.reward_status.status', 'rejected')
            ->assertJsonPath('data.0.reward_status.claim_status', 'rejected')
            ->assertJsonPath('data.0.reward_status.claimable', true);

        $secondClaim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
                'note' => 'submit again after rejection',
            ], [
                'Idempotency-Key' => 'reward-rejected-claim-resubmit',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'submitted')
            ->json();
        $this->assertNotSame($claim['id'], $secondClaim['id']);
        $this->assertSame(2, DB::table('reward_claims')->where('tenant_id', $world['tenant_id'])->where('ticket_id', $world['ticket_id'])->count());

        Event::assertDispatched(RewardClaimUpdated::class, fn (RewardClaimUpdated $event): bool => (
            ($event->payload['tenant_id'] ?? null) === $world['tenant_id']
            && ($event->payload['claim_id'] ?? null) === $secondClaim['id']
            && ($event->payload['claim']['status'] ?? null) === 'submitted'
            && ($event->payload['pending_count'] ?? null) === 1
        ));

        $this->withToken($tenantPayer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-claims?section=pending&sort_by=submitted_at&sort_dir=asc', $this->tenantClaimHeaders($world, 'reward-pending-section'))
            ->assertOk()
            ->assertJsonPath('meta.pending_count', 1)
            ->assertJsonPath('data.0.id', $secondClaim['id'])
            ->assertJsonPath('data.0.status', 'submitted');

        $this->withToken($tenantPayer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-claims?section=history&sort_by=updated_at&sort_dir=desc', $this->tenantClaimHeaders($world, 'reward-history-section'))
            ->assertOk()
            ->assertJsonPath('meta.pending_count', 1)
            ->assertJsonPath('data.0.id', $claim['id'])
            ->assertJsonPath('data.0.status', 'rejected');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'claim_submitted')
            ->assertJsonPath('claimable', false)
            ->assertJsonPath('reward_claim_id', $secondClaim['id']);
    }

    public function test_RewardClaim_customer_tickets_use_open_game_before_sale_and_history_waits_for_newer_open_game(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-29 10:00:00', 'Asia/Bangkok'));

        try {
            $old = $this->prepareRewardWorld(
                'par_reward_history',
                'ten_reward_history',
                'reward-history.m7.test',
                'gam_reward_history_old',
                '0807200500',
                790501,
            );
            $this->moveGameToDrawDate($old['game_id'], '2026-05-01 15:30:00');
            $this->publishReward($old, '999999', 'history-old');

            $latest = $this->prepareAdditionalRewardTicket(
                $old,
                'gam_reward_history_latest',
                790601,
                'history-latest',
            );
            $this->moveGameToDrawDate($latest['game_id'], '2026-05-16 15:30:00');
            $this->publishReward($latest, '999999', 'history-latest');

            $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets')
                ->assertOk()
                ->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.id', $latest['ticket_id'])
                ->assertJsonPath('data.0.game_id', $latest['game_id']);

            $initialHistory = $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets/history')
                ->assertOk()
                ->json();

            $this->assertCount(1, $initialHistory['data']);
            $this->assertSame($old['ticket_id'], $initialHistory['data'][0]['id']);
            $this->assertSame($old['game_id'], $initialHistory['data'][0]['game_id']);

            $this->insertGame('gam_rw_hist_newer', 'open');
            DB::table('games')->where('id', 'gam_rw_hist_newer')->update([
                'sale_start_at' => now()->addDay(),
                'close_at' => Carbon::parse('2026-06-01 14:30:00', 'Asia/Bangkok'),
                'closed_at' => null,
                'draw_at' => Carbon::parse('2026-06-01 15:30:00', 'Asia/Bangkok'),
                'status' => 'open',
                'updated_at' => now(),
            ]);

            $unallocatedHistory = $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets/history')
                ->assertOk()
                ->json();

            $this->assertCount(1, $unallocatedHistory['data']);
            $this->assertSame($old['ticket_id'], $unallocatedHistory['data'][0]['id']);
            $this->assertSame($old['game_id'], $unallocatedHistory['data'][0]['game_id']);

            $this->prepareOpenAllocatedGame($old, 'gam_reward_history_open', 790701, '2026-06-01 15:30:00');

            $this->getJson('http://'.$old['host'].'/api/v1/public/games/current')
                ->assertOk()
                ->assertJsonPath('id', 'gam_reward_history_open')
                ->assertJsonPath('status', 'open');

            $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets')
                ->assertOk()
                ->assertJsonCount(0, 'data');

            DB::table('games')->where('id', 'gam_reward_history_open')->update([
                'status' => 'closed',
                'closed_at' => now(),
                'updated_at' => now(),
            ]);

            $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets')
                ->assertOk()
                ->assertJsonCount(0, 'data');

            $history = $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets/history')
                ->assertOk()
                ->json();

            $this->assertCount(2, $history['data']);
            $this->assertEqualsCanonicalizing(
                [$old['ticket_id'], $latest['ticket_id']],
                array_column($history['data'], 'id'),
            );

            $latestHistory = $this->withToken($old['auth']['token'])
                ->getJson('http://'.$old['host'].'/api/v1/customer/tickets/history?game_id='.$latest['game_id'])
                ->assertOk()
                ->json();

            $this->assertCount(1, $latestHistory['data']);
            $this->assertSame($latest['ticket_id'], $latestHistory['data'][0]['id']);
            $this->assertSame($latest['game_id'], $latestHistory['data'][0]['game_id']);
            $this->assertSame('2026-05-16', substr((string) $latestHistory['data'][0]['game']['draw_at'], 0, 10));
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_RewardClaim_pay_rejects_invalid_payout_method_without_mutation(): void
    {
        $fixture = $this->submittedRewardClaim('invalid_method');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantPayer = $fixture['admin'];

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'verified before invalid pay',
            ], $this->tenantClaimHeaders($world, 'reward-invalid-method-approve'))
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $snapshot = $this->rewardClaimMutationSnapshot($world, $claim);

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/pay', [
                'payout_method' => 'crypto',
                'reason' => 'unsupported payout method',
            ], $this->tenantClaimHeaders($world, 'reward-invalid-method-pay'))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.payout_method.0', 'The payout_method field must be one of wallet_credit, bank_transfer, manual_cash.');

        $this->assertRewardClaimMutationSnapshotUnchanged($snapshot, $world, $claim);
    }

    public function test_RewardClaim_rejects_non_positive_approved_and_paid_amounts_without_mutation(): void
    {
        $fixture = $this->submittedRewardClaim('amount_validation');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantPayer = $fixture['admin'];

        foreach ([-100, 0] as $index => $amount) {
            $snapshot = $this->rewardClaimMutationSnapshot($world, $claim);

            $response = $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                    'approved_amount' => ['amount' => $amount, 'currency' => 'THB'],
                    'reason' => 'invalid approved amount',
                ], $this->tenantClaimHeaders($world, 'reward-invalid-approve-amount-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed');

            $this->assertSame('The approved_amount.amount field must be greater than zero.', $response->json('error.details.fields')['approved_amount.amount'][0] ?? null);

            $this->assertRewardClaimMutationSnapshotUnchanged($snapshot, $world, $claim);
        }

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'verified after amount validation',
            ], $this->tenantClaimHeaders($world, 'reward-valid-approve-after-amount-validation'))
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        foreach ([-100, 0] as $index => $amount) {
            $snapshot = $this->rewardClaimMutationSnapshot($world, $claim);

            $response = $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/pay', [
                    'payout_method' => 'wallet_credit',
                    'paid_amount' => ['amount' => $amount, 'currency' => 'THB'],
                    'reason' => 'invalid paid amount',
                ], $this->tenantClaimHeaders($world, 'reward-invalid-paid-amount-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed');

            $this->assertSame('The paid_amount.amount field must be greater than zero.', $response->json('error.details.fields')['paid_amount.amount'][0] ?? null);

            $this->assertRewardClaimMutationSnapshotUnchanged($snapshot, $world, $claim);
        }
    }

    public function test_RewardClaim_approve_allows_empty_reason_but_reject_and_pay_require_reason(): void
    {
        $fixture = $this->submittedRewardClaim('reason_required');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantPayer = $fixture['admin'];

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [], $this->tenantClaimHeaders($world, 'reward-approve-no-reason'))
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->assertDatabaseHas('reward_claims', [
            'id' => $claim['id'],
            'status' => 'approved',
            'admin_note' => null,
        ]);

        foreach ([[], ['reason' => '   ']] as $index => $payload) {
            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/reject', $payload, $this->tenantClaimHeaders($world, 'reward-reject-reason-required-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed')
                ->assertJsonPath('error.details.fields.reason.0', 'The reason field is required.');

            $this->assertDatabaseHas('reward_claims', [
                'id' => $claim['id'],
                'status' => 'approved',
            ]);
        }

        foreach ([['payout_method' => 'wallet_credit'], ['payout_method' => 'wallet_credit', 'reason' => '   ']] as $index => $payload) {
            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/pay', $payload, $this->tenantClaimHeaders($world, 'reward-pay-reason-required-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed')
                ->assertJsonPath('error.details.fields.reason.0', 'The reason field is required.');

            $this->assertDatabaseHas('reward_claims', [
                'id' => $claim['id'],
                'status' => 'approved',
            ]);
        }
    }

    public function test_RewardClaim_bank_transfer_and_manual_cash_payouts_remain_valid_without_wallet_ledger(): void
    {
        foreach (['bank_transfer', 'manual_cash'] as $method) {
            $fixture = $this->submittedRewardClaim('supported_'.$method);
            $world = $fixture['world'];
            $claim = $fixture['claim'];
            $tenantPayer = $fixture['admin'];

            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                    'reason' => 'verified supported payout method',
                ], $this->tenantClaimHeaders($world, 'reward-supported-'.$method.'-approve'))
                ->assertOk()
                ->assertJsonPath('status', 'approved');

            $ledgerCount = DB::table('wallet_ledger')
                ->where('tenant_id', $world['tenant_id'])
                ->where('reference_type', 'reward_claim')
                ->where('reference_id', $claim['id'])
                ->count();

            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/pay', [
                    'payout_method' => $method,
                    'reason' => 'paid through supported non-wallet method',
                ], $this->tenantClaimHeaders($world, 'reward-supported-'.$method.'-pay'))
                ->assertOk()
                ->assertJsonPath('status', 'paid')
                ->assertJsonPath('payout_method', $method);

            $this->assertSame($ledgerCount, DB::table('wallet_ledger')
                ->where('tenant_id', $world['tenant_id'])
                ->where('reference_type', 'reward_claim')
                ->where('reference_id', $claim['id'])
                ->count());
            $this->assertDatabaseHas('tickets', [
                'id' => $world['ticket_id'],
                'status' => 'paid_out',
            ]);
        }
    }

    public function test_RewardClaim_rejects_non_winning_or_cross_tenant_customer_access(): void
    {
        $world = $this->prepareRewardWorld('par_reward_lost', 'ten_reward_lost', 'reward-lost.m7.test', 'gam_reward_lost', '0807300000', 790301);
        $other = $this->prepareRewardWorld('par_reward_other', 'ten_reward_other', 'reward-other.m7.test', 'gam_reward_other', '0807300001', 790401);
        $this->publishReward($world, '999999', 'lost');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'non_winning')
            ->assertJsonPath('claimable', false);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['ticket_id'])
            ->assertJsonPath('data.0.status', 'non_winning')
            ->assertJsonPath('data.0.reward_status.status', 'non_winning');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/history')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'reward-lost-claim',
            ])
            ->assertConflict();

        $this->withToken($other['auth']['token'])
            ->getJson('http://'.$other['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertNotFound();
    }

    /**
     * @return array{world: array<string, mixed>, claim: array<string, mixed>, admin: array<string, mixed>}
     */
    private function submittedRewardClaim(string $suffix, string $payoutMethod = 'wallet_credit'): array
    {
        $digits = substr(str_pad((string) (abs(crc32($suffix)) % 100000), 5, '0', STR_PAD_LEFT), 0, 5);
        $idSuffix = substr(str_replace('_', '', strtolower($suffix)), 0, 10).substr(sha1($suffix), 0, 6);
        $safeSuffix = str_replace('_', '-', $suffix);
        $world = $this->prepareRewardWorld(
            'par_rw_'.$idSuffix,
            'ten_rw_'.$idSuffix,
            'reward-'.$safeSuffix.'.m7.test',
            'gam_rw_'.$idSuffix,
            '08074'.$digits,
            791000 + (abs(crc32($suffix)) % 1000) * 10,
        );
        $this->publishReward($world, keySuffix: $suffix);

        $payload = [
            'ticket_id' => $world['ticket_id'],
            'payout_method' => $payoutMethod,
            'pin' => '246810',
            'note' => 'validation test claim',
        ];
        if ($payoutMethod === 'bank_transfer') {
            $payload['bank_account'] = [
                'bank_name' => 'Test Bank',
                'account_name' => 'Reward Winner',
                'account_number' => '1234567890',
            ];
        }

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', $payload, [
                'Idempotency-Key' => 'reward-claim-create-'.$suffix,
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'submitted')
            ->json();

        $admin = $this->tenantAdmin($world, ['reward_claim.view', 'reward_claim.approve', 'reward_claim.reject', 'reward_claim.pay'], 'reward-'.$suffix);

        return [
            'world' => $world,
            'claim' => $claim,
            'admin' => $admin,
        ];
    }

    /**
     * @return array<string, string>
     */
    private function tenantClaimHeaders(array $world, string $idempotencyKey): array
    {
        return [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
            'Idempotency-Key' => $idempotencyKey,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function prepareAdditionalRewardTicket(array $baseWorld, string $gameId, int $stockStart, string $keySuffix): array
    {
        $this->insertGame($gameId, 'open');
        $this->insertVirtualCartSupply($baseWorld['partner_id'], $baseWorld['tenant_id'], $gameId, $stockStart);

        $reservation = $this->withToken($baseWorld['auth']['token'])
            ->postJson('http://'.$baseWorld['host'].'/api/v1/customer/reservations', [
                'game_id' => $gameId,
                'local_stock_item_ids' => [$this->firstVirtualStockRef($baseWorld['host'], $gameId, $stockStart)],
            ], [
                'Idempotency-Key' => 'reserve-'.$keySuffix,
            ])
            ->assertCreated()
            ->json();

        $world = array_merge($baseWorld, [
            'game_id' => $gameId,
            'reservation' => $reservation,
        ]);
        $order = $this->checkoutWallet($world, 'reward-checkout-'.$keySuffix);

        DB::table('games')->where('id', $gameId)->update([
            'status' => 'closed',
            'closed_at' => now(),
            'updated_at' => now(),
        ]);

        return array_merge($world, [
            'order' => $order,
            'ticket_id' => $order['tickets'][0]['id'],
            'ticket_number' => $order['tickets'][0]['full_number'],
        ]);
    }

    private function moveGameToDrawDate(string $gameId, string $drawAt): void
    {
        $drawAt = Carbon::parse($drawAt, 'Asia/Bangkok');

        DB::table('games')->where('id', $gameId)->update([
            'sale_start_at' => $drawAt->copy()->subDays(7),
            'close_at' => $drawAt->copy()->subHour(),
            'closed_at' => $drawAt->copy()->subHour(),
            'draw_at' => $drawAt,
            'status' => 'closed',
            'updated_at' => now(),
        ]);
    }

    private function prepareOpenAllocatedGame(array $baseWorld, string $gameId, int $stockStart, string $drawAt): void
    {
        $this->insertGame($gameId, 'open');
        $this->insertVirtualCartSupply($baseWorld['partner_id'], $baseWorld['tenant_id'], $gameId, $stockStart);

        $drawAt = Carbon::parse($drawAt, 'Asia/Bangkok');

        DB::table('games')->where('id', $gameId)->update([
            'sale_start_at' => now()->addDay(),
            'close_at' => $drawAt->copy()->subHour(),
            'closed_at' => null,
            'draw_at' => $drawAt,
            'status' => 'open',
            'updated_at' => now(),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function rewardClaimMutationSnapshot(array $world, array $claim): array
    {
        return [
            'claim_status' => DB::table('reward_claims')->where('id', $claim['id'])->value('status'),
            'claim_prize_amount' => DB::table('reward_claims')->where('id', $claim['id'])->value('prize_amount'),
            'claim_payout_method' => DB::table('reward_claims')->where('id', $claim['id'])->value('payout_method'),
            'claim_payout_ledger_id' => DB::table('reward_claims')->where('id', $claim['id'])->value('payout_ledger_id'),
            'claim_paid_at' => DB::table('reward_claims')->where('id', $claim['id'])->value('paid_at'),
            'winning_status' => DB::table('winning_tickets')->where('id', $claim['winning_ticket_id'])->value('status'),
            'ticket_status' => DB::table('tickets')->where('id', $world['ticket_id'])->value('status'),
            'wallet_balance' => DB::table('wallets')->where('id', $world['wallet_id'])->value('balance_amount'),
            'wallet_ledger_count' => DB::table('wallet_ledger')->where('tenant_id', $world['tenant_id'])->count(),
            'outbox_count' => DB::table('sync_outbox')->where('tenant_id', $world['tenant_id'])->count(),
        ];
    }

    private function assertRewardClaimMutationSnapshotUnchanged(array $snapshot, array $world, array $claim): void
    {
        $this->assertSame($snapshot['claim_status'], DB::table('reward_claims')->where('id', $claim['id'])->value('status'));
        $this->assertSame($snapshot['claim_prize_amount'], DB::table('reward_claims')->where('id', $claim['id'])->value('prize_amount'));
        $this->assertSame($snapshot['claim_payout_method'], DB::table('reward_claims')->where('id', $claim['id'])->value('payout_method'));
        $this->assertSame($snapshot['claim_payout_ledger_id'], DB::table('reward_claims')->where('id', $claim['id'])->value('payout_ledger_id'));
        $this->assertSame($snapshot['claim_paid_at'], DB::table('reward_claims')->where('id', $claim['id'])->value('paid_at'));
        $this->assertSame($snapshot['winning_status'], DB::table('winning_tickets')->where('id', $claim['winning_ticket_id'])->value('status'));
        $this->assertSame($snapshot['ticket_status'], DB::table('tickets')->where('id', $world['ticket_id'])->value('status'));
        $this->assertSame($snapshot['wallet_balance'], DB::table('wallets')->where('id', $world['wallet_id'])->value('balance_amount'));
        $this->assertSame($snapshot['wallet_ledger_count'], DB::table('wallet_ledger')->where('tenant_id', $world['tenant_id'])->count());
        $this->assertSame($snapshot['outbox_count'], DB::table('sync_outbox')->where('tenant_id', $world['tenant_id'])->count());
    }
}
