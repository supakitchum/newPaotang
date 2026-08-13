<?php

namespace Tests\Feature;

use App\Modules\Commerce\Events\CustomerOrderUpdated;
use App\Modules\Commerce\Events\CustomerTicketsUpdated;
use App\Modules\Commerce\Events\CustomerWalletUpdated;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class PaymentWebhookTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    private const WEBHOOK_SECRET = 'test-payment-webhook-secret-at-least-32-characters';

    public function test_PaymentWebhook_finalizes_external_payment_and_dedupes_provider_callback(): void
    {
        $world = $this->prepareReservedCart('par_payment_webhook', 'ten_payment_webhook', 'payment-webhook.m5.test', 'gam_payment_webhook', '0808009000', 770001);
        $expectedReservationAmount = 8000;
        $this->configureExternalCheckout('ten_payment_webhook');
        Event::fake([
            CustomerOrderUpdated::class,
            CustomerTicketsUpdated::class,
        ]);

        $order = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'external_payment',
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'external-checkout-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_payment')
            ->assertJsonPath('total.amount', $expectedReservationAmount)
            ->json();
        $this->assertStringStartsWith('https://checkout.provider.test/pay?', (string) ($order['redirect_url'] ?? ''));
        $this->assertStringContainsString('order_id='.rawurlencode((string) $order['id']), (string) $order['redirect_url']);
        $this->assertSame('provider_test', DB::table('payments')->where('order_id', $order['id'])->value('provider'));
        Event::assertDispatched(CustomerOrderUpdated::class, fn (CustomerOrderUpdated $event): bool =>
            ($event->payload['order_id'] ?? null) === $order['id']
            && ($event->payload['status'] ?? null) === 'pending_payment'
            && ($event->payload['ticket_ids'] ?? null) === []);
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

        $callback = [
            'id' => 'evt-payment-success',
            'event' => 'payment.succeeded',
            'reference' => $order['reference'],
            'status' => 'succeeded',
        ];

        $this->postJson('/api/v1/webhooks/payments/provider_test', $callback)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'webhook_authentication_failed');
        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'pending_payment',
            'payment_status' => 'pending',
        ]);
        $this->assertSame(0, DB::table('webhook_callbacks')->count());

        $this->postSignedWebhook('/api/v1/webhooks/payments/provider_test', $callback, now()->subMinutes(10)->timestamp)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'webhook_authentication_failed');

        $this->postSignedWebhook('/api/v1/webhooks/payments/provider_spoof', $callback)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'webhook_authentication_failed');

        $this->postSignedWebhook('/api/v1/webhooks/payments/provider_test', $callback, headers: [
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
        Event::assertDispatched(CustomerOrderUpdated::class, fn (CustomerOrderUpdated $event): bool =>
            ($event->payload['order_id'] ?? null) === $order['id']
            && ($event->payload['status'] ?? null) === 'paid'
            && count($event->payload['ticket_ids'] ?? []) === 1);
        Event::assertDispatched(CustomerTicketsUpdated::class, fn (CustomerTicketsUpdated $event): bool =>
            ($event->payload['order_id'] ?? null) === $order['id']
            && count($event->payload['ticket_ids'] ?? []) === 1);

        $this->postSignedWebhook('/api/v1/webhooks/payments/provider_test', $callback)
            ->assertAccepted()
            ->assertJsonPath('duplicate', true);

        $this->assertSame(1, DB::table('tickets')->where('order_id', $order['id'])->count());
        $this->assertSame(1, DB::table('webhook_callbacks')->where('provider', 'provider_test')->count());
        Event::assertDispatchedTimes(CustomerOrderUpdated::class, 2);
        Event::assertDispatchedTimes(CustomerTicketsUpdated::class, 1);
    }

    public function test_external_checkout_requires_runtime_provider_configuration_without_creating_an_order(): void
    {
        $world = $this->prepareReservedCart('par_payment_missing', 'ten_payment_missing', 'payment-missing.m5.test', 'gam_payment_missing', '0808009002', 770201);

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'external_payment',
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'external-checkout-missing-config',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.payment_method.0', 'This payment provider is not configured. Please contact the store.');

        $this->assertSame(0, DB::table('orders')->where('tenant_id', $world['tenant_id'])->count());
        $this->assertSame(0, DB::table('payments')->where('tenant_id', $world['tenant_id'])->count());
    }

    public function test_PaymentWebhook_accepts_topup_success_callback_and_credits_wallet_once(): void
    {
        $world = $this->prepareReservedCart('par_topup_webhook', 'ten_topup_webhook', 'topup-webhook.m5.test', 'gam_topup_webhook', '0808009001', 770101);
        $this->configureDeepayProvider('ten_topup_webhook');
        Event::fake([CustomerWalletUpdated::class]);

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 500,
            ], [
                'Idempotency-Key' => 'topup-webhook-credit',
            ])
            ->assertCreated()
            ->json();

        $partnerTxnUid = (string) DB::table('payments')->where('topup_request_id', $topup['id'])->value('provider_reference');
        $attempt = DB::table('payment_provider_attempts')->where('topup_request_id', $topup['id'])->first();

        $callback = [
            'partnerTxnUid' => $partnerTxnUid,
            'reference1' => $attempt->provider_reference1,
            'reference2' => 'wallet',
            'reference3' => $attempt->provider_reference3,
            'reference4' => $attempt->provider_reference4,
            'txnAmount' => '5.00',
            'txnCurrencyCode' => 'THB',
            'statusCode' => '00',
        ];

        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'reference1' => 'top_mismatched',
        ])
            ->assertUnauthorized();
        $this->assertDatabaseHas('topup_requests', [
            'id' => $topup['id'],
            'status' => 'processing',
        ]);

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', $callback)
            ->assertUnauthorized();
        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'partnerTxnUid' => 'ptx-arbitrary-forged',
        ])->assertUnauthorized();
        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'statusCode' => null,
        ])->assertUnauthorized();
        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'txnAmount' => '50.00',
        ])->assertUnauthorized();

        DB::table('payment_provider_attempts')->insert([
            'id' => 'pat_cancel_callback_race',
            'tenant_id' => 'ten_topup_webhook',
            'customer_id' => $world['auth']['user']['id'],
            'payment_id' => $attempt->payment_id,
            'topup_request_id' => $topup['id'],
            'provider' => 'deepay_kbank',
            'operation' => 'cancel',
            'channel' => 'credit_card',
            'status' => 'initiated',
            'request_id' => 'req-cancel-callback-race',
            'idempotency_key_hash' => hash('sha256', 'cancel-callback-race'),
            'provider_reference1' => null,
            'provider_reference2' => null,
            'provider_reference3' => null,
            'provider_reference4' => null,
            'provider_transaction_reference' => $partnerTxnUid,
            'application_error_code' => null,
            'provider_http_status' => null,
            'provider_code' => null,
            'provider_message' => null,
            'response_classification' => null,
            'latency_ms' => null,
            'attempted_at' => now()->addSecond(),
            'completed_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', $callback)
            ->assertAccepted()
            ->assertJsonPath('duplicate', false);

        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', $callback)
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
        $this->assertDatabaseHas('payment_provider_attempts', [
            'id' => 'pat_cancel_callback_race',
            'operation' => 'cancel',
            'status' => 'initiated',
            'response_classification' => null,
        ]);
        Event::assertDispatched(CustomerWalletUpdated::class, function (CustomerWalletUpdated $event) use ($world): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return ($event->payload['wallet_id'] ?? null) === $world['wallet_id']
                && ($event->payload['entry_type'] ?? null) === 'credit'
                && ($event->payload['amount'] ?? null) === 500
                && in_array('private-customer.tenant.ten_topup_webhook.customer.'.$world['auth']['user']['id'].'.wallet', $channels, true);
        });
        Event::assertDispatchedTimes(CustomerWalletUpdated::class, 1);
    }

    public function test_Deepay_trusted_provider_callback_requires_allowlisted_source_and_exact_bill_correlation(): void
    {
        config()->set('deepay.callback_trusted_ips', ['159.65.135.215']);
        $world = $this->prepareReservedCart('par_topup_trusted', 'ten_topup_trusted', 'topup-trusted.m5.test', 'gam_topup_trusted', '0808009010', 770110);
        $this->configureDeepayProvider('ten_topup_trusted', 'trusted_provider');
        Event::fake([CustomerWalletUpdated::class]);

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 600,
            ], [
                'Idempotency-Key' => 'topup-trusted-credit',
            ])
            ->assertCreated()
            ->json();

        $payment = DB::table('payments')->where('topup_request_id', $topup['id'])->first();
        $attempt = DB::table('payment_provider_attempts')->where('topup_request_id', $topup['id'])->first();
        $callback = [
            'partnerTxnUid' => $payment->provider_reference,
            'reference1' => $attempt->provider_reference1,
            'reference2' => $attempt->provider_reference2,
        ];

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', $callback, [
            'X-Forwarded-For' => '203.0.113.10',
        ])->assertUnauthorized();

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'partnerTxnUid' => 'ptx-forged',
        ], [
            'X-Forwarded-For' => '159.65.135.215',
        ])->assertUnauthorized();

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'reference3' => 'N'.str_repeat('0', 19),
        ], [
            'X-Forwarded-For' => '159.65.135.215',
        ])->assertUnauthorized();

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'txnAmount' => '60.00',
        ], [
            'X-Forwarded-For' => '159.65.135.215',
        ])->assertUnauthorized();

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            ...$callback,
            'statusCode' => '05',
        ], [
            'X-Forwarded-For' => '159.65.135.215',
        ])->assertUnauthorized();

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', $callback, [
            'X-Forwarded-For' => '159.65.135.215',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', false);

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', $callback, [
            'X-Forwarded-For' => '159.65.135.215',
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', true);

        $this->assertDatabaseHas('topup_requests', [
            'id' => $topup['id'],
            'status' => 'succeeded',
        ]);
        $this->assertDatabaseHas('payments', [
            'id' => $payment->id,
            'status' => 'succeeded',
        ]);
        $this->assertDatabaseHas('wallets', [
            'id' => $world['wallet_id'],
            'balance_amount' => 100600,
        ]);
        $this->assertSame(1, DB::table('webhook_callbacks')->where('provider', 'deepay_kbank')->count());
        Event::assertDispatchedTimes(CustomerWalletUpdated::class, 1);
    }

    public function test_Deepay_payment_callback_cannot_revive_a_cancelled_topup(): void
    {
        $world = $this->prepareReservedCart('par_topup_cancel_cb', 'ten_topup_cancel_cb', 'topup-cancelled-callback.m5.test', 'gam_topup_cancel_cb', '0808009003', 770301);
        $this->configureDeepayProvider('ten_topup_cancel_cb');

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 700,
            ], [
                'Idempotency-Key' => 'topup-cancelled-callback-create',
            ])
            ->assertCreated()
            ->json();

        $payment = DB::table('payments')->where('topup_request_id', $topup['id'])->first();
        $attempt = DB::table('payment_provider_attempts')->where('topup_request_id', $topup['id'])->whereIn('operation', ['bill', 'billCredit'])->first();
        DB::table('topup_requests')->where('id', $topup['id'])->update(['status' => 'cancelled', 'updated_at' => now()]);
        DB::table('payments')->where('id', $payment->id)->update(['status' => 'cancelled', 'updated_at' => now()]);

        $callback = [
            'partnerTxnUid' => $payment->provider_reference,
            'reference1' => $attempt->provider_reference1,
            'reference2' => $attempt->provider_reference2,
            'reference3' => $attempt->provider_reference3,
            'reference4' => $attempt->provider_reference4,
            'txnAmount' => '7.00',
            'txnCurrencyCode' => 'THB',
            'statusCode' => '00',
        ];

        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', $callback)
            ->assertUnauthorized();

        $this->assertDatabaseHas('topup_requests', ['id' => $topup['id'], 'status' => 'cancelled']);
        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'status' => 'cancelled']);
        $this->assertDatabaseHas('wallets', ['id' => $world['wallet_id'], 'balance_amount' => 100000]);
        $this->assertSame(1, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
        $this->assertSame(0, DB::table('webhook_callbacks')->where('provider', 'deepay_kbank')->count());
    }

    public function test_Deepay_authenticated_callback_credits_an_expired_topup_when_provider_cancel_was_not_confirmed(): void
    {
        $world = $this->prepareReservedCart('par_topup_expired_cb', 'ten_topup_expired_cb', 'topup-expired-callback.m5.test', 'gam_topup_expired_cb', '0808009004', 770401);
        $this->configureDeepayProvider('ten_topup_expired_cb');

        $topup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 900,
            ], [
                'Idempotency-Key' => 'topup-expired-callback-create',
            ])
            ->assertCreated()
            ->json();

        $payment = DB::table('payments')->where('topup_request_id', $topup['id'])->first();
        $attempt = DB::table('payment_provider_attempts')
            ->where('topup_request_id', $topup['id'])
            ->whereIn('operation', ['bill', 'billCredit'])
            ->first();
        DB::table('topup_requests')->where('id', $topup['id'])->update([
            'status' => 'expired',
            'payment_expires_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $callback = [
            'partnerTxnUid' => $payment->provider_reference,
            'reference1' => $attempt->provider_reference1,
            'reference2' => $attempt->provider_reference2,
            'reference3' => $attempt->provider_reference3,
            'reference4' => $attempt->provider_reference4,
            'txnAmount' => '9.00',
            'txnCurrencyCode' => 'THB',
            'statusCode' => '00',
        ];

        $this->postSignedWebhook('/api/v1/webhooks/topups/deepay_kbank', $callback)
            ->assertAccepted();

        $this->assertDatabaseHas('topup_requests', ['id' => $topup['id'], 'status' => 'succeeded']);
        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'status' => 'succeeded']);
        $this->assertDatabaseHas('wallets', ['id' => $world['wallet_id'], 'balance_amount' => 100900]);
        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
    }

    private function configureDeepayProvider(string $tenantId, string $webhookAuthMode = 'hmac_sha256'): void
    {
        DB::table('tenant_payment_provider_connections')->updateOrInsert(
            ['tenant_id' => $tenantId, 'provider' => 'deepay_kbank'],
            [
                'id' => 'tpc_'.substr(hash('sha256', $tenantId), 0, 20),
                'status' => 'active',
                'api_key_encrypted' => Crypt::encryptString('test-deepay-key'),
                'webhook_secret_encrypted' => $webhookAuthMode === 'trusted_provider'
                    ? null
                    : Crypt::encryptString(self::WEBHOOK_SECRET),
                'verified_at' => now(),
                'last_tested_at' => now(),
                'last_test_status' => 'ok',
                'last_error' => null,
                'metadata_json' => json_encode([
                    'webhook_auth_mode' => $webhookAuthMode,
                ], JSON_THROW_ON_ERROR),
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

    private function configureExternalCheckout(string $tenantId): void
    {
        DB::table('tenant_payment_provider_connections')->updateOrInsert(
            ['tenant_id' => $tenantId, 'provider' => 'provider_test'],
            [
                'id' => 'tpc_'.substr(hash('sha256', $tenantId.':provider-test'), 0, 20),
                'status' => 'active',
                'api_key_encrypted' => Crypt::encryptString('test-provider-key'),
                'webhook_secret_encrypted' => Crypt::encryptString(self::WEBHOOK_SECRET),
                'verified_at' => now(),
                'last_tested_at' => now(),
                'last_test_status' => 'ok',
                'last_error' => null,
                'metadata_json' => json_encode([
                    'webhook_auth_mode' => 'hmac_sha256',
                ], JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );

        DB::table('tenant_payment_settings')->updateOrInsert(
            ['tenant_id' => $tenantId],
            [
                'id' => 'tps_'.substr(hash('sha256', $tenantId.':external-checkout'), 0, 20),
                'status' => 'active',
                'provider_mode' => 'external_configured',
                'default_currency' => 'THB',
                'allow_manual_topup' => true,
                'allow_external_payment' => true,
                'payment_provider_status' => 'local_dev_configured',
                'config_json' => json_encode([
                    'checkout' => [
                        'external_payment' => [
                            'provider' => 'provider_test',
                            'redirect_url_template' => 'https://checkout.provider.test/pay?order_id={order_id}&reference={reference}&amount={amount_minor}&callback={callback_url}',
                        ],
                    ],
                ], JSON_THROW_ON_ERROR),
                'secret_status_json' => json_encode([], JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, string> $headers
     */
    private function postSignedWebhook(
        string $uri,
        array $payload,
        ?int $timestamp = null,
        array $headers = [],
    ): \Illuminate\Testing\TestResponse {
        $content = json_encode($payload, JSON_THROW_ON_ERROR);
        $timestamp = $timestamp ?? now()->timestamp;
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_WEBHOOK_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_SIGNATURE' => 'sha256='.hash_hmac(
                'sha256',
                $timestamp.'.'.$content,
                self::WEBHOOK_SECRET,
            ),
        ];
        foreach ($headers as $key => $value) {
            $server['HTTP_'.strtoupper(str_replace('-', '_', $key))] = $value;
        }

        return $this->call('POST', $uri, [], [], [], $server, $content);
    }
}
