<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class PaymentWebhookTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_PaymentWebhook_finalizes_external_payment_and_dedupes_provider_callback(): void
    {
        $world = $this->prepareReservedCart('par_payment_webhook', 'ten_payment_webhook', 'payment-webhook.m5.test', 'gam_payment_webhook', '0808009000', 770001);
        $expectedReservationAmount = 8000;

        $order = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'external_payment',
            ], [
                'Idempotency-Key' => 'external-checkout-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_payment')
            ->assertJsonPath('total.amount', $expectedReservationAmount)
            ->json();
        $this->assertDatabaseHas('order_items', [
            'tenant_id' => 'ten_payment_webhook',
            'order_id' => $order['id'],
            'status' => 'reserved',
            'price_amount' => $expectedReservationAmount,
        ]);

        DB::table('game_sale_price_rules')->insert([
            'id' => 'gsp_payment_webhook_late',
            'game_id' => 'gam_payment_webhook',
            'set_size' => 1,
            'price_amount' => 12900,
            'currency' => 'THB',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

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
        $this->assertDatabaseHas('order_items', [
            'tenant_id' => 'ten_payment_webhook',
            'order_id' => $order['id'],
            'status' => 'sold',
            'price_amount' => $expectedReservationAmount,
        ]);
        $snapshot = json_decode((string) DB::table('order_items')->where('order_id', $order['id'])->value('sale_price_rule_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertNull($snapshot['central_rule_id'] ?? null);
        $this->assertTrue((bool) ($snapshot['fallback'] ?? false));
        $this->assertSame($expectedReservationAmount, $snapshot['effective_amount']['amount'] ?? null);
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
        $this->configureDeepayProvider('ten_topup_webhook');

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 500,
            ], [
                'Idempotency-Key' => 'topup-webhook-credit',
            ])
            ->assertCreated()
            ->json();

        $partnerTxnUid = (string) DB::table('payments')->where('topup_request_id', $topup['id'])->value('provider_reference');

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            'partnerTxnUid' => $partnerTxnUid,
            'reference1' => $topup['id'],
            'reference2' => 'wallet',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', false);

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            'partnerTxnUid' => $partnerTxnUid,
            'reference1' => $topup['id'],
            'reference2' => 'wallet',
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

    private function configureDeepayProvider(string $tenantId): void
    {
        DB::table('tenant_payment_provider_connections')->updateOrInsert(
            ['tenant_id' => $tenantId, 'provider' => 'deepay_kbank'],
            [
                'id' => 'tpc_'.substr(hash('sha256', $tenantId), 0, 20),
                'status' => 'active',
                'api_key_encrypted' => Crypt::encryptString('test-deepay-key'),
                'verified_at' => now(),
                'last_tested_at' => now(),
                'last_test_status' => 'ok',
                'last_error' => null,
                'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );

        Http::fake(function ($request) {
            $reference1 = (string) data_get($request->data(), 'reference1', 'top_test');

            return Http::response([
                'result' => [
                    'qr' => base64_encode('qr-'.$reference1),
                    'txn' => [
                        'response' => [
                            'partnerTxnUid' => 'ptx_'.$reference1,
                        ],
                    ],
                ],
            ], 200);
        });
    }
}
