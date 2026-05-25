<?php

namespace Tests\Feature;

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

        $login = $this->postJson('http://auth.m5.test/api/v1/customer/auth/login', [
            'username' => '0801002000',
            'password' => 'customer-secret',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id'])
            ->json();

        $refreshed = $this->postJson('http://auth.m5.test/api/v1/customer/auth/refresh', [
            'refresh_token' => $login['refresh_token'],
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $registered['user']['id'])
            ->json();

        $this->withToken($refreshed['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/auth/me')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id']);

        $this->withToken($refreshed['token'])
            ->getJson('http://auth.m5.test/api/v1/customer/profile')
            ->assertOk()
            ->assertJsonPath('id', $registered['user']['id']);

        $this->withToken($refreshed['token'])
            ->patchJson('http://auth.m5.test/api/v1/customer/profile', [
                'name' => 'Customer Updated',
                'avatar_url' => 'https://cdn.example.test/avatar.png',
                'reward_payout_bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_name' => 'Customer Updated',
                    'account_number' => '1234567890',
                ],
            ], [
                'Idempotency-Key' => 'profile-update-m5',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Customer Updated')
            ->assertJsonPath('reward_payout_bank_account.bank_name', 'Example Bank')
            ->assertJsonPath('reward_payout_bank_account.account_number', '1234567890');

        $this->withToken($refreshed['token'])
            ->postJson('http://auth.m5.test/api/v1/customer/auth/logout', [], [
                'Idempotency-Key' => 'logout-auth-m5',
            ])
            ->assertNoContent();

        $this->assertNotNull(DB::table('customer_auth_sessions')->where('access_token_hash', hash('sha256', $refreshed['token']))->value('revoked_at'));
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
