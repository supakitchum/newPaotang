<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerAuthTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_CustomerAuth_register_login_refresh_profile_and_logout_are_tenant_scoped_and_secret_safe(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_auth_m5', 'ten_auth_m5', 'auth.m5.test');

        $this->postJson('http://auth.m5.test/api/v1/customer/auth/register', [
            'name' => 'Customer Auth',
            'phone' => '0801002000',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ])->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $registered = $this->postJson('http://auth.m5.test/api/v1/customer/auth/register', [
            'name' => 'Customer Auth',
            'phone' => '0801002000',
            'email' => 'customer-auth@example.test',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ], [
            'Idempotency-Key' => 'register-auth-m5',
        ])
            ->assertCreated()
            ->assertJsonMissing(['password_hash'])
            ->assertJsonMissing(['access_token_hash'])
            ->assertJsonPath('user.tenant_id', 'ten_auth_m5')
            ->assertJsonPath('user.has_pin', false)
            ->assertJsonPath('pin_setup_required', true)
            ->json();

        $this->assertDatabaseHas('customers', [
            'id' => $registered['user']['id'],
            'tenant_id' => 'ten_auth_m5',
            'phone' => '0801002000',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('wallets', [
            'tenant_id' => 'ten_auth_m5',
            'customer_id' => $registered['user']['id'],
            'type' => 'primary',
        ]);
        DB::table('wallets')
            ->where('tenant_id', 'ten_auth_m5')
            ->where('customer_id', $registered['user']['id'])
            ->where('type', 'primary')
            ->update(['name' => 'Runtime Blue Wallet']);

        $login = $this->postJson('http://auth.m5.test/api/v1/customer/auth/login', [
            'username' => '0801002000',
            'password' => 'customer-secret',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id'])
            ->assertJsonPath('user.wallet.name', 'Runtime Blue Wallet')
            ->assertJsonPath('user.primary_wallet.name', 'Runtime Blue Wallet')
            ->json();
        $loginSession = DB::table('customer_auth_sessions')
            ->where('access_token_hash', hash('sha256', $login['token']))
            ->first();
        $this->assertNotNull($loginSession);
        $this->assertTrue(CarbonImmutable::parse((string) $loginSession->refresh_expires_at)->greaterThanOrEqualTo(now()->addDays(29)));

        $refreshed = $this->postJson('http://auth.m5.test/api/v1/customer/auth/refresh', [
            'refresh_token' => $login['refresh_token'],
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id'])
            ->assertJsonPath('user.has_pin', false)
            ->assertJsonPath('pin_setup_required', true)
            ->json();

        $this->withToken($refreshed['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/profile')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'pin_setup_required');

        $this->withToken($refreshed['token'])
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/setup', [
                'pin' => '123456',
                'pin_confirmation' => '123456',
            ])
            ->assertOk()
            ->assertJsonPath('has_pin', true)
            ->assertJsonPath('pin_verified', true)
            ->assertJsonPath('user.pin_setup_required', false);

        $this->withToken($refreshed['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/auth/me')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id'])
            ->assertJsonPath('has_pin', true)
            ->assertJsonPath('pin_verified', true);

        $this->withToken($refreshed['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/profile')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id'])
            ->assertJsonPath('wallet.name', 'Runtime Blue Wallet')
            ->assertJsonPath('primary_wallet.name', 'Runtime Blue Wallet');

        $this->withToken($refreshed['token'])
            ->patchJson('http://auth.m5.test/api/v1/customer/profile', [
                'reward_payout_bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_name' => 'Customer Updated',
                    'account_number' => '1234567890',
                ],
            ], [
                'Idempotency-Key' => 'profile-bank-missing-pin-m5',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.pin.0', 'The pin field must contain exactly 6 digits.');

        $this->withToken($refreshed['token'])
            ->patchJson('http://auth.m5.test/api/v1/customer/profile', [
                'reward_payout_bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_name' => 'Customer Updated',
                    'account_number' => '1234567890',
                ],
                'pin' => '000000',
            ], [
                'Idempotency-Key' => 'profile-bank-wrong-pin-m5',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'pin_invalid');

        $this->withToken($refreshed['token'])
            ->patchJson('http://auth.m5.test/api/v1/customer/profile', [
                'name' => 'Customer Updated',
                'avatar_url' => 'https://cdn.example.test/avatar.png',
                'reward_payout_bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_name' => 'Customer Updated',
                    'account_number' => '1234567890',
                ],
                'auto_reward_claim' => [
                    'enabled' => true,
                    'type' => 'bank_transfer',
                ],
                'pin' => '123456',
            ], [
                'Idempotency-Key' => 'profile-update-m5',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Customer Updated')
            ->assertJsonPath('reward_payout_bank_account.bank_name', 'Example Bank')
            ->assertJsonPath('reward_payout_bank_account.account_number', '1234567890')
            ->assertJsonPath('auto_reward_claim.enabled', true)
            ->assertJsonPath('auto_reward_claim.payout_method', 'bank_transfer')
            ->assertJsonPath('auto_reward_claim.type', 'bank_transfer');

        $lockedLogin = $this->postJson('http://auth.m5.test/api/v1/customer/auth/login', [
            'username' => '0801002000',
            'password' => 'customer-secret',
        ])
            ->assertOk()
            ->assertJsonPath('pin_required', true)
            ->assertJsonPath('user.has_pin', true)
            ->assertJsonPath('user.pin_verified', false)
            ->json();

        $this->withToken($lockedLogin['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/profile')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'pin_required');

        DB::table('customer_auth_sessions')
            ->where('access_token_hash', hash('sha256', $lockedLogin['token']))
            ->update([
                'access_expires_at' => now()->subMinute(),
                'updated_at' => now(),
            ]);

        $this->withToken($lockedLogin['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $refreshedLockedLogin = $this->postJson('http://auth.m5.test/api/v1/customer/auth/refresh', [
            'refresh_token' => $lockedLogin['refresh_token'],
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id'])
            ->assertJsonPath('pin_required', true)
            ->assertJsonPath('user.has_pin', true)
            ->assertJsonPath('user.pin_verified', false)
            ->json();
        $pinLockedToken = $refreshedLockedLogin['token'];

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/verify', [
                'pin' => '000000',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'pin_invalid');

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/reset', [
                'pin' => '654321',
                'pin_confirmation' => '654321',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'pin_reset_not_verified');

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/reset/verify-password', [
                'password' => 'wrong-secret',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'password_invalid');

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/reset/verify-password', [
                'password' => 'customer-secret',
            ])
            ->assertOk()
            ->assertJsonPath('reset_verified', true);

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/reset', [
                'pin' => '654321',
                'pin_confirmation' => '654322',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/reset', [
                'pin' => '654321',
                'pin_confirmation' => '654321',
            ])
            ->assertOk()
            ->assertJsonPath('has_pin', true)
            ->assertJsonPath('pin_verified', true);

        $this->withToken($pinLockedToken)
            ->postJson('http://auth.m5.test/api/v1/customer/auth/pin/verify', [
                'pin' => '654321',
            ])
            ->assertOk()
            ->assertJsonPath('has_pin', true)
            ->assertJsonPath('pin_verified', true);

        $this->withToken($pinLockedToken)
            ->getJson('http://auth.m5.test/api/v1/customer/profile')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id']);

        $this->withToken($refreshed['token'])
            ->postJson('http://auth.m5.test/api/v1/customer/auth/logout', [], [
                'Idempotency-Key' => 'logout-auth-m5',
            ])
            ->assertNoContent();

        $this->assertNotNull(DB::table('customer_auth_sessions')->where('access_token_hash', hash('sha256', $refreshed['token']))->value('revoked_at'));
    }

    public function test_CustomerAuth_blocks_suspended_customers_with_reason_and_auto_reactivates_expired_suspensions(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_auth_suspend', 'ten_auth_suspend', 'auth-suspend.m5.test');

        $registered = $this->postJson('http://auth-suspend.m5.test/api/v1/customer/auth/register', [
            'name' => 'Suspended Customer',
            'phone' => '0801002999',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ], [
            'Idempotency-Key' => 'register-auth-suspended-m5',
        ])->assertCreated()->json();

        DB::table('customers')->where('id', $registered['user']['id'])->update([
            'status' => 'suspended',
            'suspended_at' => now(),
            'suspended_until' => now()->addDays(3),
            'suspension_reason' => 'ตรวจสอบความเสี่ยง',
            'suspended_by_admin_id' => 'adm_test',
            'updated_at' => now(),
        ]);

        $this->postJson('http://auth-suspend.m5.test/api/v1/customer/auth/login', [
            'username' => '0801002999',
            'password' => 'customer-secret',
        ])->assertForbidden()
            ->assertJsonPath('error.code', 'customer_suspended')
            ->assertJsonPath('error.details.suspension.reason', 'ตรวจสอบความเสี่ยง')
            ->assertJsonPath('error.details.suspension.is_permanent', false);

        $this->withToken($registered['token'])
            ->getJson('http://auth-suspend.m5.test/api/v1/customer/auth/me')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'customer_suspended')
            ->assertJsonPath('error.details.suspension.reason', 'ตรวจสอบความเสี่ยง');

        $this->postJson('http://auth-suspend.m5.test/api/v1/customer/auth/refresh', [
            'refresh_token' => $registered['refresh_token'],
        ])->assertForbidden()
            ->assertJsonPath('error.code', 'customer_suspended');

        $this->assertNotNull(DB::table('customer_auth_sessions')
            ->where('access_token_hash', hash('sha256', $registered['token']))
            ->value('revoked_at'));

        DB::table('customers')->where('id', $registered['user']['id'])->update([
            'status' => 'suspended',
            'suspended_until' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $this->postJson('http://auth-suspend.m5.test/api/v1/customer/auth/login', [
            'username' => '0801002999',
            'password' => 'customer-secret',
        ])->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id']);

        $this->assertDatabaseHas('customers', [
            'id' => $registered['user']['id'],
            'status' => 'active',
            'suspension_reason' => null,
            'suspended_until' => null,
        ]);
    }

    public function test_CustomerAuth_rejects_bearer_session_on_different_tenant_host_without_revoking_session(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_auth_a_m5', 'ten_auth_a_m5', 'auth-a.m5.test');
        $this->insertActivePartnerTenantWithDomain('par_auth_b_m5', 'ten_auth_b_m5', 'auth-b.m5.test');

        $registered = $this->postJson('http://auth-a.m5.test/api/v1/customer/auth/register', [
            'name' => 'Tenant A Customer',
            'phone' => '0801003000',
            'email' => 'tenant-a-customer@example.test',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ], [
            'Idempotency-Key' => 'register-auth-a-m5',
        ])
            ->assertCreated()
            ->json();

        $token = $registered['token'];
        $sessionHash = hash('sha256', $token);

        $this->withToken($token)
            ->getJson('http://auth-b.m5.test/api/v1/customer/auth/me')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied')
            ->assertJsonMissing(['id' => $registered['user']['id']]);

        $this->withToken($token)
            ->getJson('http://auth-b.m5.test/api/v1/customer/profile')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied')
            ->assertJsonMissing(['id' => $registered['user']['id']]);

        $this->withToken($token)
            ->patchJson('http://auth-b.m5.test/api/v1/customer/profile', [
                'name' => 'Cross Tenant Update',
            ], [
                'Idempotency-Key' => 'profile-cross-tenant-m5',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied')
            ->assertJsonMissing(['id' => $registered['user']['id']]);

        $this->assertDatabaseHas('customers', [
            'id' => $registered['user']['id'],
            'tenant_id' => 'ten_auth_a_m5',
            'name' => 'Tenant A Customer',
        ]);

        $this->withToken($token)
            ->postJson('http://auth-b.m5.test/api/v1/customer/auth/logout', [], [
                'Idempotency-Key' => 'logout-cross-tenant-m5',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->assertNull(DB::table('customer_auth_sessions')->where('access_token_hash', $sessionHash)->value('revoked_at'));

        $this->withToken($token)
            ->getJson('http://auth-a.m5.test/api/v1/customer/auth/me')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id']);

        $this->withToken($token)
            ->postJson('http://auth-a.m5.test/api/v1/customer/auth/logout', [], [
                'Idempotency-Key' => 'logout-same-tenant-m5',
            ])
            ->assertNoContent();

        $this->assertNotNull(DB::table('customer_auth_sessions')->where('access_token_hash', $sessionHash)->value('revoked_at'));
    }
}
