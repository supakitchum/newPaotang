<?php

namespace Tests\Feature;

use App\Modules\SmsOtp\Services\SmsOtpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerSmsOtpTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_CustomerSmsOtp_register_requires_verified_token_when_tenant_provider_is_active(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_register', 'ten_sms_register', 'sms-register.m5.test');
        $this->insertSmsProvider('ten_sms_register');
        Http::fake(['api-v2.thaibulksms.com/*' => Http::response(['message_id' => 'sms-register-1'], 200)]);

        $this->postJson('http://sms-register.m5.test/api/v1/customer/auth/register', [
            'name' => 'SMS Register',
            'phone' => '0801112222',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ], [
            'Idempotency-Key' => 'register-without-otp',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.otp_verification_token.0', 'OTP verification is required before registration.');

        $this->postJson('http://sms-register.m5.test/api/v1/customer/auth/otp/request', [
            'phone' => '0801112222',
            'purpose' => 'register',
        ])->assertAccepted()
            ->assertJsonPath('status', 'sent');

        $this->forceLatestOtp('ten_sms_register', '0801112222', 'register', '123456');

        $verified = $this->postJson('http://sms-register.m5.test/api/v1/customer/auth/otp/verify', [
            'phone' => '0801112222',
            'purpose' => 'register',
            'otp' => '123456',
        ])->assertOk()
            ->json('otp_verification_token');

        $this->postJson('http://sms-register.m5.test/api/v1/customer/auth/register', [
            'name' => 'SMS Register',
            'phone' => '0801112222',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
            'otp_verification_token' => $verified,
        ], [
            'Idempotency-Key' => 'register-with-otp',
        ])
            ->assertCreated()
            ->assertJsonPath('user.tenant_id', 'ten_sms_register');

        $this->assertDatabaseHas('sms_delivery_logs', [
            'tenant_id' => 'ten_sms_register',
            'purpose' => 'register',
            'status' => 'sent',
        ]);
    }

    public function test_CustomerSmsOtp_resets_password_and_pin_with_verified_otp(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_reset', 'ten_sms_reset', 'sms-reset.m5.test');
        $this->insertSmsProvider('ten_sms_reset');
        Http::fake(['api-v2.thaibulksms.com/*' => Http::response(['message_id' => 'sms-reset-1'], 200)]);

        $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/otp/request', [
            'phone' => '0803334444',
            'purpose' => 'register',
        ])->assertAccepted();
        $this->forceLatestOtp('ten_sms_reset', '0803334444', 'register', '111111');
        $registerToken = $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/otp/verify', [
            'phone' => '0803334444',
            'purpose' => 'register',
            'otp' => '111111',
        ])->assertOk()->json('otp_verification_token');

        $registered = $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/register', [
            'name' => 'SMS Reset',
            'phone' => '0803334444',
            'password' => 'old-secret',
            'password_confirmation' => 'old-secret',
            'otp_verification_token' => $registerToken,
        ], [
            'Idempotency-Key' => 'sms-reset-register',
        ])->assertCreated()->json();

        $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/otp/request', [
            'phone' => '0803334444',
            'purpose' => 'password_reset',
        ])->assertAccepted();
        $this->forceLatestOtp('ten_sms_reset', '0803334444', 'password_reset', '222222');
        $passwordToken = $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/otp/verify', [
            'phone' => '0803334444',
            'purpose' => 'password_reset',
            'otp' => '222222',
        ])->assertOk()->json('otp_verification_token');

        $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/password/reset/otp', [
            'phone' => '0803334444',
            'otp_verification_token' => $passwordToken,
            'password' => 'new-secret',
            'password_confirmation' => 'new-secret',
        ])->assertOk()
            ->assertJsonPath('status', 'password_reset');

        $login = $this->postJson('http://sms-reset.m5.test/api/v1/customer/auth/login', [
            'username' => '0803334444',
            'password' => 'new-secret',
        ])->assertOk()->json();

        $this->withToken($login['token'])
            ->postJson('http://sms-reset.m5.test/api/v1/customer/auth/pin/setup', [
                'pin' => '123456',
                'pin_confirmation' => '123456',
            ])->assertOk();

        $this->withToken($login['token'])
            ->postJson('http://sms-reset.m5.test/api/v1/customer/auth/pin/reset/request-otp')
            ->assertAccepted();
        $this->forceLatestOtp('ten_sms_reset', '0803334444', 'pin_reset', '333333');
        $pinToken = $this->withToken($login['token'])
            ->postJson('http://sms-reset.m5.test/api/v1/customer/auth/pin/reset/verify-otp', [
                'otp' => '333333',
            ])->assertOk()->json('otp_verification_token');

        $this->withToken($login['token'])
            ->postJson('http://sms-reset.m5.test/api/v1/customer/auth/pin/reset/confirm-otp', [
                'otp_verification_token' => $pinToken,
                'pin' => '654321',
                'pin_confirmation' => '654321',
            ])->assertOk()
            ->assertJsonPath('has_pin', true)
            ->assertJsonPath('pin_verified', true);

        $this->assertDatabaseHas('customer_password_reset_requests', [
            'tenant_id' => 'ten_sms_reset',
            'customer_id' => $registered['user']['id'],
            'channel' => 'sms_otp',
            'status' => 'consumed',
        ]);
    }

    public function test_TenantSmsOtp_test_send_can_use_configured_inactive_provider(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_test', 'ten_sms_test', 'sms-test.m5.test');
        $this->insertSmsProvider('ten_sms_test', 'inactive');
        Http::fake(['api-v2.thaibulksms.com/*' => Http::response(['message_id' => 'sms-test-1'], 200)]);

        $result = app(SmsOtpService::class)->testSend('ten_sms_test', [
            'phone' => '0805556666',
        ]);

        $this->assertSame('sent', $result['resource']['status'] ?? null);
        $this->assertDatabaseHas('sms_delivery_logs', [
            'tenant_id' => 'ten_sms_test',
            'purpose' => 'register',
            'status' => 'sent',
            'provider_message_id' => 'sms-test-1',
        ]);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_test',
            'status' => 'inactive',
            'last_test_status' => 'sent',
        ]);
    }

    public function test_TenantSmsOtp_test_send_handles_structured_provider_errors_without_500(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_error', 'ten_sms_error', 'sms-error.m5.test');
        $this->insertSmsProvider('ten_sms_error');
        Http::fake([
            'api-v2.thaibulksms.com/*' => Http::response([
                'error' => [
                    'code' => 110,
                    'name' => 'ERROR_SENDER',
                    'description' => 'Sender is invalid.',
                ],
            ], 400),
        ]);

        $result = app(SmsOtpService::class)->testSend('ten_sms_error', [
            'phone' => '0807778888',
        ]);

        $this->assertSame('sms_test_failed', $result['error'] ?? null);
        $this->assertSame(503, $result['status'] ?? null);
        $this->assertStringContainsString('ERROR_SENDER', $result['message'] ?? '');
        $this->assertStringContainsString('Sender is invalid.', $result['message'] ?? '');
        $this->assertDatabaseHas('sms_delivery_logs', [
            'tenant_id' => 'ten_sms_error',
            'purpose' => 'register',
            'status' => 'failed',
            'http_status' => 400,
            'error_message' => 'ERROR_SENDER: Sender is invalid.: 110',
        ]);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_error',
            'last_test_status' => 'failed',
            'last_test_message' => 'ERROR_SENDER: Sender is invalid.: 110',
        ]);
    }

    public function test_TenantSmsOtp_rejects_invalid_thaibulk_sender_name_before_save(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_sender', 'ten_sms_sender', 'sms-sender.m5.test');

        $result = app(SmsOtpService::class)->updateProvider('ten_sms_sender', [
            'provider' => 'thaibulk',
            'status' => 'active',
            'api_key' => 'test-api-key',
            'api_secret' => 'test-api-secret',
            'sender_name' => 'พบโชค',
        ]);

        $this->assertSame('validation_failed', $result['error'] ?? null);
        $this->assertStringContainsString('Sender ID is invalid', $result['errors']['sender_name'][0] ?? '');
        $this->assertDatabaseMissing('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_sender',
        ]);
    }

    public function test_TenantSmsOtp_test_send_handles_legacy_invalid_sender_without_calling_provider(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_legacy_sender', 'ten_sms_legacy_sender', 'sms-legacy-sender.m5.test');
        $this->insertSmsProvider('ten_sms_legacy_sender', 'active', 'พบโชค');
        Http::fake(['api-v2.thaibulksms.com/*' => Http::response(['message_id' => 'should-not-send'], 200)]);

        $result = app(SmsOtpService::class)->testSend('ten_sms_legacy_sender', [
            'phone' => '0809990000',
        ]);

        $this->assertSame('sms_test_failed', $result['error'] ?? null);
        $this->assertSame(422, $result['status'] ?? null);
        $this->assertStringContainsString('Sender ID is invalid', $result['message'] ?? '');
        Http::assertNothingSent();
        $this->assertDatabaseHas('sms_delivery_logs', [
            'tenant_id' => 'ten_sms_legacy_sender',
            'purpose' => 'register',
            'status' => 'failed',
            'http_status' => 422,
        ]);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_legacy_sender',
            'last_test_status' => 'failed',
        ]);
    }

    public function test_TenantSmsOtp_provider_rows_can_be_enabled_and_disabled_exclusively(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sms_rows', 'ten_sms_rows', 'sms-rows.m5.test');
        $this->insertSmsProvider('ten_sms_rows', 'active');
        DB::table('tenant_sms_providers')->insert([
            'id' => 'tsp_future_sms_rows',
            'tenant_id' => 'ten_sms_rows',
            'provider' => 'future_sms',
            'status' => 'inactive',
            'api_key_encrypted' => Crypt::encryptString('future-key'),
            'api_secret_encrypted' => Crypt::encryptString('future-secret'),
            'sender_name' => 'FUTURE',
            'verified_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $settings = app(SmsOtpService::class)->settings('ten_sms_rows');

        $this->assertCount(2, $settings['providers']);
        $this->assertSame('thaibulk', $settings['providers'][0]['provider']);
        $this->assertSame('active', $settings['providers'][0]['status']);

        $activated = app(SmsOtpService::class)->updateProviderStatus('ten_sms_rows', 'tsp_future_sms_rows', [
            'status' => 'active',
        ]);

        $this->assertSame('future_sms', $activated['resource']['providers'][0]['provider'] ?? null);
        $this->assertSame('active', $activated['resource']['providers'][0]['status'] ?? null);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_rows',
            'provider' => 'thaibulk',
            'status' => 'inactive',
        ]);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_rows',
            'provider' => 'future_sms',
            'status' => 'active',
        ]);

        $deactivated = app(SmsOtpService::class)->updateProviderStatus('ten_sms_rows', 'tsp_future_sms_rows', [
            'status' => 'inactive',
        ]);

        $this->assertSame('inactive', $deactivated['resource']['providers'][0]['status'] ?? null);
        $this->assertDatabaseHas('tenant_sms_providers', [
            'tenant_id' => 'ten_sms_rows',
            'provider' => 'future_sms',
            'status' => 'inactive',
        ]);
    }

    private function insertSmsProvider(string $tenantId, string $status = 'active', string $senderName = 'TEST'): void
    {
        DB::table('tenant_sms_providers')->insert([
            'id' => 'tsp_'.substr(sha1($tenantId), 0, 20),
            'tenant_id' => $tenantId,
            'provider' => 'thaibulk',
            'status' => $status,
            'api_key_encrypted' => Crypt::encryptString('test-api-key'),
            'api_secret_encrypted' => Crypt::encryptString('test-api-secret'),
            'sender_name' => $senderName,
            'verified_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function forceLatestOtp(string $tenantId, string $phone, string $purpose, string $otp): void
    {
        $id = DB::table('otp_verifications')
            ->where('tenant_id', $tenantId)
            ->where('phone_normalized', $phone)
            ->where('purpose', $purpose)
            ->orderByDesc('created_at')
            ->value('id');

        DB::table('otp_verifications')
            ->where('id', $id)
            ->update([
                'otp_hash' => Hash::make($otp),
                'attempts' => 0,
                'status' => 'pending',
                'expires_at' => now()->addMinutes(5),
                'updated_at' => now(),
            ]);
    }
}
