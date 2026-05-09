<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class PaymentWebhookTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_PaymentWebhook_finalizes_external_payment_and_dedupes_provider_callback(): void
    {
        $world = $this->prepareReservedCart('par_payment_webhook', 'ten_payment_webhook', 'payment-webhook.m5.test', 'gam_payment_webhook', '0808009000', 770001);

        $order = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'external_payment',
            ], [
                'Idempotency-Key' => 'external-checkout-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_payment')
            ->json();

        $this->assertDatabaseHas('local_stock_items', [
            'id' => $world['local_ids'][0],
            'status' => 'reserved',
        ]);

        $this->postJson('/api/v1/webhooks/payments/external_payment', [
            'id' => 'evt-payment-success',
            'event' => 'payment.succeeded',
            'reference' => $order['reference'],
            'status' => 'succeeded',
        ], [
            'X-Request-Id' => 'req-payment-webhook',
        ])
            ->assertAccepted()
            ->assertJsonPath('accepted', true)
            ->assertJsonPath('duplicate', false);

        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'paid',
            'payment_status' => 'paid',
        ]);
        $this->assertDatabaseHas('local_stock_items', [
            'id' => $world['local_ids'][0],
            'status' => 'sold',
        ]);
        $this->assertSame(1, DB::table('tickets')->where('order_id', $order['id'])->count());

        $this->postJson('/api/v1/webhooks/payments/external_payment', [
            'id' => 'evt-payment-success',
            'event' => 'payment.succeeded',
            'reference' => $order['reference'],
            'status' => 'succeeded',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', true);

        $this->assertSame(1, DB::table('tickets')->where('order_id', $order['id'])->count());
        $this->assertSame(1, DB::table('webhook_callbacks')->where('provider', 'external_payment')->count());
    }

    public function test_PaymentWebhook_accepts_topup_success_callback_and_credits_wallet_once(): void
    {
        $world = $this->prepareReservedCart('par_topup_webhook', 'ten_topup_webhook', 'topup-webhook.m5.test', 'gam_topup_webhook', '0808009001', 770101);
        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 500,
            ], [
                'Idempotency-Key' => 'topup-webhook-credit',
            ])
            ->assertCreated()
            ->json();

        $reference = DB::table('topup_requests')->where('id', $topup['id'])->value('reference');

        $this->postJson('/api/v1/webhooks/topups/credit_card', [
            'id' => 'evt-topup-success',
            'event' => 'topup.succeeded',
            'reference' => $reference,
            'status' => 'succeeded',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', false);

        $this->postJson('/api/v1/webhooks/topups/credit_card', [
            'id' => 'evt-topup-success',
            'event' => 'topup.succeeded',
            'reference' => $reference,
            'status' => 'succeeded',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', true);

        $this->assertDatabaseHas('topup_requests', [
            'id' => $topup['id'],
            'status' => 'succeeded',
        ]);
        $this->assertDatabaseHas('wallets', [
            'id' => $world['wallet_id'],
            'balance_amount' => 100500,
        ]);
        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
    }
}
