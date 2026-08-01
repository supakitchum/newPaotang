<?php

namespace Tests\Feature;

use App\Modules\Auth\Services\CustomerAccountDeletionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerAccountDeletionTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('cache.default', 'array');
        Cache::clear();
    }

    public function test_customer_confirms_pin_and_otp_then_enters_read_only_grace_period_and_can_cancel(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_delete', 'ten_delete', 'delete.test');
        $token = $this->issueCustomerToken('ten_delete', 'cus_delete');
        $this->insertWallet('ten_delete', 'cus_delete', 0);
        $this->insertSmsProvider('ten_delete');
        $this->fakeOtp();

        $this->withToken($token)
            ->getJson('http://delete.test/api/v1/customer/account-deletion')
            ->assertOk()
            ->assertJsonPath('eligibility.eligible', true)
            ->assertJsonPath('request', null);

        $otpRequest = $this->withToken($token)
            ->postJson('http://delete.test/api/v1/customer/account-deletion/request-otp', [
                'pin' => '246810',
            ])
            ->assertAccepted()
            ->json();

        $otpToken = $this->withToken($token)
            ->postJson('http://delete.test/api/v1/customer/account-deletion/verify-otp', [
                'otp' => '123456',
            ])
            ->assertOk()
            ->json('otp_verification_token');

        $created = $this->withToken($token)
            ->postJson('http://delete.test/api/v1/customer/account-deletion', [
                'reason_code' => 'privacy',
                'reason_detail' => 'Privacy request',
                'pin_verification_token' => $otpRequest['pin_verification_token'],
                'otp_verification_token' => $otpToken,
            ], [
                'Idempotency-Key' => 'delete-customer-request',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('read_only', true)
            ->json();

        $this->assertGreaterThan(604700, $created['remaining_seconds']);
        $this->withToken($token)
            ->postJson('http://delete.test/api/v1/customer/topups', [
                'amount' => 100,
            ])
            ->assertStatus(423)
            ->assertJsonPath('error.code', 'account_deletion_pending');
        $this->withToken($token)
            ->getJson('http://delete.test/api/v1/customer/profile')
            ->assertOk();

        $this->withToken($token)
            ->postJson('http://delete.test/api/v1/customer/account-deletion/cancel', [
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'cancel-customer-request',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled');

        $this->assertDatabaseHas('customer_account_deletion_requests', [
            'tenant_id' => 'ten_delete',
            'customer_id' => 'cus_delete',
            'status' => 'cancelled',
        ]);
    }

    public function test_outstanding_wallet_blocks_request_and_due_request_closes_without_deleting_evidence(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_due', 'ten_due', 'due-delete.test');
        $token = $this->issueCustomerToken('ten_due', 'cus_due');
        $this->insertWallet('ten_due', 'cus_due', 500);

        $this->withToken($token)
            ->getJson('http://due-delete.test/api/v1/customer/account-deletion/eligibility')
            ->assertOk()
            ->assertJsonPath('eligible', false)
            ->assertJsonPath('blockers.0.code', 'wallet_balance');

        DB::table('wallets')->where('customer_id', 'cus_due')->update(['balance_amount' => 0]);
        DB::table('customer_account_deletion_requests')->insert([
            'id' => 'cad_due',
            'tenant_id' => 'ten_due',
            'customer_id' => 'cus_due',
            'status' => 'pending',
            'reason_code' => 'no_longer_use',
            'idempotency_key' => 'due-delete-request',
            'payload_hash' => hash('sha256', 'due'),
            'pin_verified_at' => now()->subDays(8),
            'otp_verified_at' => now()->subDays(8),
            'requested_at' => now()->subDays(8),
            'scheduled_for' => now()->subMinute(),
            'created_at' => now()->subDays(8),
            'updated_at' => now()->subDays(8),
        ]);

        $result = app(CustomerAccountDeletionService::class)->processDue();
        $this->assertSame(1, $result['completed']);
        $this->assertDatabaseHas('customers', [
            'id' => 'cus_due',
            'status' => 'deleted',
            'phone' => DB::table('customers')->where('id', 'cus_due')->value('phone'),
        ]);
        $this->assertDatabaseHas('wallets', [
            'customer_id' => 'cus_due',
            'balance_amount' => 0,
        ]);
        $this->assertDatabaseHas('customer_account_deletion_requests', [
            'id' => 'cad_due',
            'status' => 'completed',
        ]);
        $this->assertDatabaseHas('customer_auth_sessions', [
            'customer_id' => 'cus_due',
            'revoked_reason' => 'account_deleted',
        ]);
    }

    public function test_deleted_phone_is_blocked_for_90_days_then_can_register_as_a_new_customer(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_reuse', 'ten_reuse', 'reuse-delete.test');
        $this->issueCustomerToken('ten_reuse', 'cus_old');
        $phone = DB::table('customers')->where('id', 'cus_old')->value('phone');
        DB::table('customers')->where('id', 'cus_old')->update([
            'status' => 'deleted',
            'deleted_at' => now(),
            'phone_reuse_after' => now()->addDays(90),
        ]);

        $payload = [
            'name' => 'New Customer',
            'phone' => $phone,
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ];
        $this->postJson('http://reuse-delete.test/api/v1/customer/auth/register', $payload, [
            'Idempotency-Key' => 'reuse-before-cooldown',
        ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'account_reuse_cooldown');

        DB::table('customers')->where('id', 'cus_old')->update([
            'phone_reuse_after' => now()->subSecond(),
        ]);
        $this->postJson('http://reuse-delete.test/api/v1/customer/auth/register', $payload, [
            'Idempotency-Key' => 'reuse-after-cooldown',
        ])
            ->assertCreated()
            ->assertJsonPath('user.phone', $phone);

        $this->assertSame(
            2,
            DB::table('customers')->where('tenant_id', 'ten_reuse')->where('phone', $phone)->count(),
        );
    }

    private function insertWallet(string $tenantId, string $customerId, int $balance): void
    {
        DB::table('wallets')->insert([
            'id' => 'wal_'.substr(sha1($customerId), 0, 20),
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'type' => 'primary',
            'name' => 'Primary wallet',
            'status' => 'active',
            'balance_amount' => $balance,
            'currency' => 'THB',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertSmsProvider(string $tenantId): void
    {
        DB::table('tenant_sms_providers')->insert([
            'id' => 'tsp_'.substr(sha1($tenantId), 0, 20),
            'tenant_id' => $tenantId,
            'provider' => 'thaibulk',
            'status' => 'active',
            'api_key_encrypted' => Crypt::encryptString('test-api-key'),
            'api_secret_encrypted' => Crypt::encryptString('test-api-secret'),
            'sender_name' => 'TEST',
            'verified_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function fakeOtp(): void
    {
        Http::fake([
            '*otp.thaibulksms.com/v2/otp/request' => Http::response([
                'status' => 'success',
                'token' => 'delete-provider-token',
                'refno' => 'DEL01',
            ], 201),
            '*otp.thaibulksms.com/v2/otp/verify' => Http::response([
                'status' => 'success',
                'message' => 'Code is correct.',
            ], 200),
        ]);
    }
}
