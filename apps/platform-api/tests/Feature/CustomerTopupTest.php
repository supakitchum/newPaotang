<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class CustomerTopupTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_CustomerTopup_create_credit_list_detail_and_replay_are_tenant_scoped(): void
    {
        $world = $this->prepareReservedCart('par_cust_topup', 'ten_cust_topup', 'customer-topup.m5.test', 'gam_cust_topup', '0804005000', 730001);
        $transferAt = now()->toISOString();

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'bank_transfer',
                'amount' => 20000,
                'transfer_at' => $transferAt,
            ], [
                'Idempotency-Key' => 'customer-topup-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_review')
            ->json();

        $replay = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'bank_transfer',
                'amount' => 20000,
                'transfer_at' => $transferAt,
            ], [
                'Idempotency-Key' => 'customer-topup-main',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame($topup['id'], $replay['id']);

        $credit = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 400,
            ], [
                'Idempotency-Key' => 'customer-credit-topup',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_payment')
            ->json();

        $this->assertDatabaseHas('payments', [
            'tenant_id' => 'ten_cust_topup',
            'topup_request_id' => $credit['id'],
            'status' => 'pending',
        ]);

        $overview = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups')
            ->assertOk()
            ->json();

        $this->assertContains($credit['id'], array_column($overview['histories'], 'id'));

        $cancelledCredit = $this->withToken($world['auth']['token'])
            ->deleteJson('http://'.$world['host'].'/api/v1/customer/topups/'.$credit['id'], [
                'reason' => 'Changed payment method',
            ], [
                'Idempotency-Key' => 'customer-credit-cancel',
            ])
            ->assertOk()
            ->assertJsonPath('id', $credit['id'])
            ->assertJsonPath('status', 'cancelled')
            ->json();

        $cancelReplay = $this->withToken($world['auth']['token'])
            ->deleteJson('http://'.$world['host'].'/api/v1/customer/topups/'.$credit['id'], [
                'reason' => 'Changed payment method',
            ], [
                'Idempotency-Key' => 'customer-credit-cancel',
            ])
            ->assertOk()
            ->json();

        $this->assertSame($cancelledCredit['id'], $cancelReplay['id']);
        $this->assertDatabaseHas('payments', [
            'tenant_id' => 'ten_cust_topup',
            'topup_request_id' => $credit['id'],
            'status' => 'cancelled',
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups/'.$topup['id'])
            ->assertOk()
            ->assertJsonPath('id', $topup['id']);

        $this->assertSame(2, DB::table('topup_requests')->where('tenant_id', 'ten_cust_topup')->count());
    }
}
