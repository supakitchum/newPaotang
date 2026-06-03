<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    public function test_CustomerTopup_accepts_slip_uploads_and_exposes_admin_preview_metadata(): void
    {
        $disk = (string) config('lottery_images.disk', 'lottery_images');
        Storage::fake($disk);

        $world = $this->prepareReservedCart('par_cust_slip', 'ten_cust_slip', 'customer-slip.m5.test', 'gam_cust_slip', '0804005111', 730101);
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

        $updated = $this->withToken($world['auth']['token'])
            ->post('http://'.$world['host'].'/api/v1/customer/topups/'.$qrTopup['id'].'/slip', [
                'slip' => $this->uploadedSlip(),
            ], [
                'Idempotency-Key' => 'customer-topup-qr-slip-later',
            ])
            ->assertOk()
            ->assertJsonPath('id', $qrTopup['id'])
            ->assertJsonPath('slip.expires_at', fn (?string $value): bool => $value !== null)
            ->json();

        $this->assertNotNull($updated['slip_thumb_url'] ?? null);
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

    private function uploadedSlip(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'topup-slip-').'.webp';
        file_put_contents($path, base64_decode('UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA'));

        return new UploadedFile($path, 'customer-slip.webp', 'image/webp', null, true);
    }
}
