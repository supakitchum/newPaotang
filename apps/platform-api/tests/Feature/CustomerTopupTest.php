<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Http\UploadedFile;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class CustomerTopupTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_CustomerTopup_create_credit_list_detail_and_replay_are_tenant_scoped(): void
    {
        $world = $this->prepareReservedCart('par_cust_topup', 'ten_cust_topup', 'customer-topup.m5.test', 'gam_cust_topup', '0804005000', 730001);
        $this->configureDeepayProvider('ten_cust_topup');
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
            ->assertJsonPath('payment.qr_code', fn (?string $value): bool => is_string($value) && $value !== '')
            ->json();

        $this->assertDatabaseHas('payments', [
            'tenant_id' => 'ten_cust_topup',
            'topup_request_id' => $credit['id'],
            'status' => 'pending',
        ]);
        Http::assertSent(fn ($request): bool => str_ends_with($request->url(), '/billCredit')
            && str_starts_with((string) data_get($request->data(), 'reference1'), 'T')
            && strlen((string) data_get($request->data(), 'reference1')) <= 20
            && data_get($request->data(), 'reference2') === 'wallet'
            && str_starts_with((string) data_get($request->data(), 'reference3'), 'N')
            && strlen((string) data_get($request->data(), 'reference3')) <= 20
            && data_get($request->data(), 'reference4') === 'credit_card');

        $providerReference = (string) DB::table('payments')
            ->where('topup_request_id', $credit['id'])
            ->value('provider_reference');

        $overview = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups')
            ->assertOk()
            ->assertJsonPath('wallet.id', $world['wallet_id'])
            ->assertJsonPath('wallet.name', 'Primary wallet')
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
        Http::assertSent(fn ($request): bool => str_ends_with($request->url(), '/cancel')
            && data_get($request->data(), 'txn_id') === $providerReference);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups/'.$topup['id'])
            ->assertOk()
            ->assertJsonPath('id', $topup['id']);

        $this->assertSame(2, DB::table('topup_requests')->where('tenant_id', 'ten_cust_topup')->count());
    }

    public function test_CustomerTopup_respects_tenant_payment_method_toggles(): void
    {
        $world = $this->prepareReservedCart('par_cust_topup_toggle', 'ten_cust_topup_toggle', 'customer-topup-toggle.m5.test', 'gam_cust_topup_toggle', '0804005001', 730101);

        DB::table('tenant_payment_settings')->insert([
            'id' => 'tps_customer_topup_toggle',
            'tenant_id' => 'ten_cust_topup_toggle',
            'status' => 'active',
            'provider_mode' => 'manual_only',
            'default_currency' => 'THB',
            'allow_manual_topup' => true,
            'allow_external_payment' => false,
            'payment_provider_status' => 'manual_only',
            'config_json' => json_encode([
                'payment_methods' => [
                    'qr' => ['enabled' => false],
                    'credit_card' => ['enabled' => false],
                    'bank_transfer' => ['enabled' => true],
                ],
            ], JSON_THROW_ON_ERROR),
            'secret_status_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups')
            ->assertOk()
            ->assertJsonPath('payment_methods.0.key', 'qr')
            ->assertJsonPath('payment_methods.0.enabled', false)
            ->assertJsonPath('payment_methods.1.key', 'credit_card')
            ->assertJsonPath('payment_methods.1.enabled', false)
            ->assertJsonPath('payment_methods.2.key', 'bank_transfer')
            ->assertJsonPath('payment_methods.2.enabled', true)
            ->assertJsonPath('enabled_payment_methods.0', 'bank_transfer');

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'qr',
                'amount' => 20000,
            ], [
                'Idempotency-Key' => 'customer-topup-disabled-qr',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.channel.0', 'This payment method is currently disabled.');

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups/credit', [
                'amount' => 400,
            ], [
                'Idempotency-Key' => 'customer-topup-disabled-credit',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.channel.0', 'This payment method is currently disabled.');

        $bankTopup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'bank_transfer',
                'amount' => 20000,
                'transfer_at' => now()->toISOString(),
            ], [
                'Idempotency-Key' => 'customer-topup-enabled-bank-transfer',
            ])
            ->assertCreated()
            ->json();

        $this->assertDatabaseHas('topup_requests', [
            'id' => $bankTopup['id'],
            'tenant_id' => 'ten_cust_topup_toggle',
            'channel' => 'bank_transfer',
        ]);
    }

    public function test_CustomerTopup_requires_configured_provider_for_provider_backed_methods(): void
    {
        $world = $this->prepareReservedCart('par_cust_provider_miss', 'ten_cust_provider_miss', 'customer-topup-provider-missing.m5.test', 'gam_cust_provider_miss', '0804005002', 730102);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/topups')
            ->assertOk()
            ->assertJsonPath('payment_methods.0.key', 'qr')
            ->assertJsonPath('payment_methods.0.enabled', false)
            ->assertJsonPath('payment_methods.1.key', 'credit_card')
            ->assertJsonPath('payment_methods.1.enabled', false)
            ->assertJsonPath('payment_methods.2.key', 'bank_transfer')
            ->assertJsonPath('payment_methods.2.enabled', true)
            ->assertJsonPath('enabled_payment_methods.0', 'bank_transfer');

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'qr',
                'amount' => 20000,
            ], [
                'Idempotency-Key' => 'customer-topup-missing-provider-qr',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.channel.0', 'This payment provider is not configured. Please contact the store.');
    }

    public function test_CustomerWallet_ledger_lists_current_customer_movements(): void
    {
        $world = $this->prepareReservedCart('par_cust_wallet', 'ten_cust_wallet', 'customer-wallet.m5.test', 'gam_cust_wallet', '0804005333', 730301);
        DB::table('wallet_ledger')
            ->where('wallet_id', $world['wallet_id'])
            ->where('reference_type', 'test_seed')
            ->update([
                'posted_at' => now()->subMinute(),
                'created_at' => now()->subMinute(),
                'updated_at' => now()->subMinute(),
            ]);

        $order = $this->checkoutWallet($world, 'customer-wallet-ledger-checkout');

        $response = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=5&sort_by=created_at&sort_dir=desc')
            ->assertOk()
            ->assertJsonPath('data.0.reference_type', 'order')
            ->assertJsonPath('data.0.reference_id', $order['id'])
            ->assertJsonPath('data.0.amount.amount', -8000)
            ->json();

        $this->assertContains('test_seed', array_column($response['data'], 'reference_type'));
        $this->assertSame('ten_cust_wallet', $response['data'][0]['tenant_id']);
        $this->assertSame($world['auth']['user']['id'], $response['data'][0]['customer_id']);
    }

    public function test_CustomerWallet_ledger_paginates_descending_rows_and_filters_money_direction(): void
    {
        $world = $this->prepareReservedCart('par_cust_wallet_page', 'ten_cust_wallet_page', 'customer-wallet-page.m5.test', 'gam_cust_wallet_page', '0804005444', 730401);
        DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->delete();

        $baseTime = now()->startOfSecond();
        $movements = [
            ['id' => 'wle_page_006', 'amount' => 6000, 'created_at' => $baseTime],
            ['id' => 'wle_page_005', 'amount' => -5000, 'created_at' => $baseTime],
            ['id' => 'wle_page_004', 'amount' => 4000, 'created_at' => $baseTime->copy()->subMinute()],
            ['id' => 'wle_page_003', 'amount' => -3000, 'created_at' => $baseTime->copy()->subMinutes(2)],
            ['id' => 'wle_page_002', 'amount' => 2000, 'created_at' => $baseTime->copy()->subMinutes(3)],
            ['id' => 'wle_page_001', 'amount' => -1000, 'created_at' => $baseTime->copy()->subMinutes(4)],
        ];

        foreach ($movements as $movement) {
            DB::table('wallet_ledger')->insert([
                'id' => $movement['id'],
                'tenant_id' => 'ten_cust_wallet_page',
                'wallet_id' => $world['wallet_id'],
                'customer_id' => $world['auth']['user']['id'],
                'entry_type' => $movement['amount'] > 0 ? 'credit' : 'debit',
                'status' => 'posted',
                'amount' => $movement['amount'],
                'currency' => 'THB',
                'balance_after' => 100000,
                'reference_type' => 'pagination_test',
                'reference_id' => $movement['id'],
                'posted_at' => $movement['created_at'],
                'created_at' => $movement['created_at'],
                'updated_at' => $movement['created_at'],
            ]);
        }

        $first = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=2&sort_by=created_at&sort_dir=desc')
            ->assertOk()
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->assertSame(['wle_page_006', 'wle_page_005'], array_column($first['data'], 'id'));
        $this->assertStringStartsWith('v1.', $first['meta']['next_cursor']);

        $second = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=2&sort_by=created_at&sort_dir=desc&cursor='.rawurlencode($first['meta']['next_cursor']))
            ->assertOk()
            ->json();

        $this->assertSame(['wle_page_004', 'wle_page_003'], array_column($second['data'], 'id'));
        $this->assertSame([], array_intersect(array_column($first['data'], 'id'), array_column($second['data'], 'id')));

        $incoming = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=2&direction=incoming&sort_by=created_at&sort_dir=desc')
            ->assertOk()
            ->json();
        $this->assertSame(['wle_page_006', 'wle_page_004'], array_column($incoming['data'], 'id'));

        $incomingNext = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=2&direction=incoming&sort_by=created_at&sort_dir=desc&cursor='.rawurlencode($incoming['meta']['next_cursor']))
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json();
        $this->assertSame(['wle_page_002'], array_column($incomingNext['data'], 'id'));

        $outgoing = $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/wallet/ledger?limit=3&direction=outgoing&sort_by=created_at&sort_dir=desc')
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json();
        $this->assertSame(['wle_page_005', 'wle_page_003', 'wle_page_001'], array_column($outgoing['data'], 'id'));
    }

    public function test_CustomerTopup_accepts_slip_uploads_and_exposes_admin_preview_metadata(): void
    {
        $disk = (string) config('lottery_images.disk', 'lottery_images');
        Storage::fake($disk);

        $world = $this->prepareReservedCart('par_cust_slip', 'ten_cust_slip', 'customer-slip.m5.test', 'gam_cust_slip', '0804005111', 730101);
        $this->configureDeepayProvider('ten_cust_slip');
        $transferAt = now()->toISOString();

        $topup = $this->withToken($world['auth']['token'])
            ->post('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'bank_transfer',
                'amount' => 20000,
                'transfer_at' => $transferAt,
                'slip' => $this->uploadedSlip(),
            ], [
                'Idempotency-Key' => 'customer-topup-slip',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_review')
            ->assertJsonPath('slip.expires_at', fn (?string $value): bool => $value !== null)
            ->json();

        $row = DB::table('topup_requests')->where('id', $topup['id'])->first();

        $this->assertNotNull($row?->slip_storage_path);
        $this->assertNotNull($row?->slip_thumb_storage_path);
        $this->assertNotNull($row?->slip_expires_at);
        Storage::disk($disk)->assertExists((string) $row->slip_storage_path);
        Storage::disk($disk)->assertExists((string) $row->slip_thumb_storage_path);

        $manager = $this->tenantAdmin($world, ['topup.view'], 'topupslipview');

        $this->withToken($manager['access_token'])
            ->getJson('/api/v1/admin/tenant/topups/'.$topup['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_cust_slip',
            ])
            ->assertOk()
            ->assertJsonPath('slip.expires_at', fn (?string $value): bool => $value !== null)
            ->assertJsonPath('slip_thumb_url', fn (?string $value): bool => $value !== null);

        $qrTopup = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'qr',
                'amount' => 15000,
            ], [
                'Idempotency-Key' => 'customer-topup-qr-before-slip',
            ])
            ->assertCreated()
            ->assertJsonPath('payment.qr_code', fn (?string $value): bool => is_string($value) && $value !== '')
            ->assertJsonPath('slip', null)
            ->json();
        Http::assertSent(fn ($request): bool => str_ends_with($request->url(), '/bill')
            && str_starts_with((string) data_get($request->data(), 'reference1'), 'T')
            && strlen((string) data_get($request->data(), 'reference1')) <= 20
            && data_get($request->data(), 'reference2') === 'wallet'
            && strlen((string) data_get($request->data(), 'reference3')) <= 20
            && data_get($request->data(), 'reference4') === 'qr');

        $this->withToken($world['auth']['token'])
            ->post('http://'.$world['host'].'/api/v1/customer/topups/'.$qrTopup['id'].'/slip', [
                'slip' => $this->uploadedSlip(),
            ], [
                'Idempotency-Key' => 'customer-topup-qr-slip-later',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'pending_review')
            ->assertJsonPath('slip.expires_at', fn (?string $value): bool => $value !== null);

        $qrRow = DB::table('topup_requests')->where('id', $qrTopup['id'])->first();
        $this->assertSame('pending', $qrRow?->status);
        $this->assertNotNull($qrRow?->slip_storage_path);
    }

    public function test_CustomerTopup_realtime_auth_allows_only_the_current_customer_topup_channel(): void
    {
        $world = $this->prepareReservedCart('par_cust_topup_rt', 'ten_cust_topup_rt', 'customer-topup-rt.m5.test', 'gam_cust_topup_rt', '0804005222', 730201);
        $customerId = (string) $world['auth']['user']['id'];

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/realtime/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-customer.tenant.ten_cust_topup_rt.customer.'.$customerId.'.topups',
            ])
            ->assertOk()
            ->assertJsonPath('auth', fn (?string $value): bool => is_string($value) && str_contains($value, ':'));

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/realtime/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-customer.tenant.ten_cust_topup_rt.customer.cus_other.topups',
            ])
            ->assertForbidden();
    }

    public function test_Deepay_rejection_is_durable_safe_and_idempotent_outside_the_topup_transaction(): void
    {
        $world = $this->prepareReservedCart('par_deepay_reject', 'ten_deepay_reject', 'deepay-reject.m5.test', 'gam_deepay_reject', '0804005333', 730301);
        $baselineTransactionLevel = DB::transactionLevel();
        $providerTransactionLevel = null;

        $this->configureDeepayProvider('ten_deepay_reject', function ($request) use (&$providerTransactionLevel) {
            $providerTransactionLevel = DB::transactionLevel();

            return Http::response([
                'code' => 1000,
                'reference1' => ['The reference1 may not be greater than 20 characters. <script>unsafe()</script>'],
            ], 400);
        });

        $headers = [
            'Idempotency-Key' => 'deepay-rejected-once',
            'X-Request-Id' => 'req-deepay-rejected-once',
        ];
        $payload = ['channel' => 'qr', 'amount' => 15000];

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', $payload, $headers)
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_failed')
            ->assertJsonPath('error.request_id', 'req-deepay-rejected-once')
            ->assertJsonMissingPath('error.details.provider_message');

        $this->assertSame($baselineTransactionLevel, $providerTransactionLevel);
        Http::assertSentCount(1);

        $attempt = DB::table('payment_provider_attempts')->where('request_id', 'req-deepay-rejected-once')->first();
        $this->assertNotNull($attempt);
        $this->assertSame('provider_rejected', $attempt->status);
        $this->assertSame(400, $attempt->provider_http_status);
        $this->assertSame('payment_provider_failed', $attempt->application_error_code);
        $this->assertLessThanOrEqual(20, strlen((string) $attempt->provider_reference1));
        $this->assertLessThanOrEqual(20, strlen((string) $attempt->provider_reference3));
        $this->assertStringNotContainsString('<script>', (string) $attempt->provider_message);
        $this->assertStringNotContainsString('test-deepay-key', json_encode((array) $attempt, JSON_THROW_ON_ERROR));

        $this->assertDatabaseHas('topup_requests', [
            'id' => $attempt->topup_request_id,
            'status' => 'failed',
        ]);
        $this->assertDatabaseHas('payments', [
            'id' => $attempt->payment_id,
            'status' => 'failed',
        ]);

        $viewer = $this->tenantAdmin($world, ['topup.view'], 'deepayrejectview');
        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/topups?request_id=req-deepay-rejected-once', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_deepay_reject',
            ])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $attempt->topup_request_id);
        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/topups/'.$attempt->topup_request_id, [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_deepay_reject',
            ])
            ->assertOk()
            ->assertJsonPath('provider_attempt.request_id', 'req-deepay-rejected-once')
            ->assertJsonPath('provider_attempt.provider_http_status', 400)
            ->assertJsonMissingPath('provider_payload.qr_code')
            ->assertJsonMissingPath('provider_payload.response');

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', $payload, $headers)
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_failed');

        Http::assertSentCount(1);
        $this->assertSame(1, DB::table('payment_provider_attempts')->where('tenant_id', 'ten_deepay_reject')->count());
        $this->assertSame(1, DB::table('topup_requests')->where('tenant_id', 'ten_deepay_reject')->count());
        $this->assertSame(1, DB::table('payments')->where('tenant_id', 'ten_deepay_reject')->count());
    }

    public function test_Deepay_invalid_success_response_is_preserved_as_unknown_without_a_second_bill(): void
    {
        $world = $this->prepareReservedCart('par_deepay_invalid', 'ten_deepay_invalid', 'deepay-invalid.m5.test', 'gam_deepay_invalid', '0804005444', 730401);
        $this->configureDeepayProvider(
            'ten_deepay_invalid',
            fn () => Http::response(['code' => 0, 'result' => []], 200),
        );

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                'channel' => 'qr',
                'amount' => 16000,
            ], [
                'Idempotency-Key' => 'deepay-invalid-response',
                'X-Request-Id' => 'req-deepay-invalid-response',
            ])
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_invalid_response');

        $attempt = DB::table('payment_provider_attempts')->where('request_id', 'req-deepay-invalid-response')->first();
        $this->assertNotNull($attempt);
        $this->assertSame('invalid_response', $attempt->status);
        $this->assertSame('invalid_response', $attempt->response_classification);
        $this->assertDatabaseHas('topup_requests', ['id' => $attempt->topup_request_id, 'status' => 'processing']);
        $this->assertDatabaseHas('payments', ['id' => $attempt->payment_id, 'status' => 'processing']);
        Http::assertSentCount(1);

        $this->withToken($world['auth']['token'])
            ->deleteJson('http://'.$world['host'].'/api/v1/customer/topups/'.$attempt->topup_request_id, [
                'reason' => 'try another payment',
            ], [
                'Idempotency-Key' => 'deepay-invalid-cancel',
            ])
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_outcome_unknown');
        $this->assertDatabaseHas('topup_requests', ['id' => $attempt->topup_request_id, 'status' => 'processing']);
        Http::assertSentCount(1);
    }

    public function test_Deepay_connection_failure_is_outcome_unknown_and_is_not_retried(): void
    {
        $world = $this->prepareReservedCart('par_deepay_timeout', 'ten_deepay_timeout', 'deepay-timeout.m5.test', 'gam_deepay_timeout', '0804005555', 730501);
        $this->configureDeepayProvider(
            'ten_deepay_timeout',
            fn () => Http::failedConnection('simulated timeout containing test-deepay-key'),
        );
        $payload = ['channel' => 'qr', 'amount' => 17000];
        $headers = [
            'Idempotency-Key' => 'deepay-timeout-once',
            'X-Request-Id' => 'req-deepay-timeout-once',
        ];

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', $payload, $headers)
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_outcome_unknown')
            ->assertJsonPath('error.request_id', 'req-deepay-timeout-once');

        $attempt = DB::table('payment_provider_attempts')->where('request_id', 'req-deepay-timeout-once')->first();
        $this->assertNotNull($attempt);
        $this->assertSame('outcome_unknown', $attempt->status);
        $this->assertSame('outcome_unknown', $attempt->response_classification);
        $this->assertStringNotContainsString('test-deepay-key', json_encode((array) $attempt, JSON_THROW_ON_ERROR));
        $this->assertDatabaseHas('topup_requests', ['id' => $attempt->topup_request_id, 'status' => 'processing']);
        $this->assertDatabaseHas('payments', ['id' => $attempt->payment_id, 'status' => 'processing']);

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', $payload, $headers)
            ->assertStatus(502)
            ->assertJsonPath('error.code', 'payment_provider_outcome_unknown');

        Http::assertSentCount(1);
        $this->assertSame(1, DB::table('payment_provider_attempts')->where('tenant_id', 'ten_deepay_timeout')->count());

        $this->postJson('/api/v1/webhooks/topups/deepay_kbank', [
            'partnerTxnUid' => 'ptx-resolved-after-timeout',
            'reference1' => $attempt->provider_reference1,
            'reference2' => 'wallet',
            'reference3' => $attempt->provider_reference3,
        ])
            ->assertAccepted()
            ->assertJsonPath('duplicate', false);

        $this->assertDatabaseHas('payment_provider_attempts', [
            'id' => $attempt->id,
            'status' => 'succeeded',
            'provider_transaction_reference' => 'ptx-resolved-after-timeout',
            'response_classification' => 'succeeded_callback',
        ]);
        $this->assertDatabaseHas('topup_requests', ['id' => $attempt->topup_request_id, 'status' => 'succeeded']);
        $this->assertDatabaseHas('payments', [
            'id' => $attempt->payment_id,
            'status' => 'succeeded',
            'provider_reference' => 'ptx-resolved-after-timeout',
        ]);
        $this->assertDatabaseHas('wallets', [
            'id' => $world['wallet_id'],
            'balance_amount' => 117000,
        ]);

        $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/topups', $payload, $headers)
            ->assertCreated()
            ->assertJsonPath('id', $attempt->topup_request_id)
            ->assertJsonPath('status', 'approved');
        Http::assertSentCount(1);
    }

    private function uploadedSlip(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'topup-slip-').'.webp';
        file_put_contents($path, base64_decode('UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA'));

        return new UploadedFile($path, 'customer-slip.webp', 'image/webp', null, true);
    }

    private function configureDeepayProvider(string $tenantId, ?callable $responseFactory = null): void
    {
        DB::table('tenant_payment_provider_connections')->updateOrInsert(
            ['tenant_id' => $tenantId, 'provider' => 'deepay_kbank'],
            [
                'id' => 'tpc_'.substr(hash('sha256', $tenantId), 0, 20),
                'status' => 'active',
                'api_key_encrypted' => Crypt::encryptString('test-deepay-key'),
                'webhook_secret_encrypted' => Crypt::encryptString('test-topup-webhook-secret-at-least-32-characters'),
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

        Http::fake($responseFactory ?? function ($request) {
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
