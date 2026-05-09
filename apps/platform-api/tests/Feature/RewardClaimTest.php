<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M7RewardFixtures;
use Tests\TestCase;

class RewardClaimTest extends TestCase
{
    use M7RewardFixtures;
    use RefreshDatabase;

    public function test_RewardClaim_customer_status_claim_and_tenant_approve_pay_are_scoped_idempotent_and_ledger_based(): void
    {
        $world = $this->prepareRewardWorld('par_reward_claim', 'ten_reward_claim', 'reward-claim.m7.test', 'gam_reward_claim', '0807200000', 790201);
        $this->publishReward($world, keySuffix: 'claim');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets/'.$world['ticket_id'].'/reward-status')
            ->assertOk()
            ->assertJsonPath('status', 'winning')
            ->assertJsonPath('claimable', true)
            ->assertJsonPath('prize_amount.amount', 1000000);

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'note' => 'please credit wallet',
            ], [
                'Idempotency-Key' => 'reward-claim-create',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'submitted')
            ->json();

        $replay = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
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
            'amount' => 1000000,
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

    public function test_RewardClaim_approve_reject_and_pay_require_reason(): void
    {
        $fixture = $this->submittedRewardClaim('reason_required');
        $world = $fixture['world'];
        $claim = $fixture['claim'];
        $tenantPayer = $fixture['admin'];

        foreach ([[], ['reason' => '   ']] as $index => $payload) {
            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', $payload, $this->tenantClaimHeaders($world, 'reward-approve-reason-required-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed')
                ->assertJsonPath('error.details.fields.reason.0', 'The reason field is required.');

            $this->assertDatabaseHas('reward_claims', [
                'id' => $claim['id'],
                'status' => 'submitted',
            ]);
        }

        foreach ([[], ['reason' => '   ']] as $index => $payload) {
            $this->withToken($tenantPayer['access_token'])
                ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/reject', $payload, $this->tenantClaimHeaders($world, 'reward-reject-reason-required-'.$index))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'validation_failed')
                ->assertJsonPath('error.details.fields.reason.0', 'The reason field is required.');

            $this->assertDatabaseHas('reward_claims', [
                'id' => $claim['id'],
                'status' => 'submitted',
            ]);
        }

        $this->withToken($tenantPayer['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$claim['id'].'/approve', [
                'reason' => 'verified for pay reason test',
            ], $this->tenantClaimHeaders($world, 'reward-pay-reason-approve'))
            ->assertOk()
            ->assertJsonPath('status', 'approved');

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
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
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
    private function submittedRewardClaim(string $suffix): array
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

        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'wallet_credit',
                'note' => 'validation test claim',
            ], [
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
