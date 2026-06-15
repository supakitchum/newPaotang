<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Tests\Support\AdminAuthFixtures;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerPasswordResetTest extends TestCase
{
    use AdminAuthFixtures;
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_customer_can_request_admin_issued_password_reset_link_and_set_new_password(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_pwd', 'ten_pwd', 'password-reset.test');

        DB::table('customers')->insert([
            'id' => 'cus_pwd',
            'tenant_id' => 'ten_pwd',
            'customer_no' => 'PWD000001',
            'phone' => '0801003000',
            'email' => 'pwd@example.test',
            'name' => 'Password Customer',
            'password_hash' => Hash::make('old-secret'),
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson('http://password-reset.test/api/v1/customer/auth/password/forgot', [
            'phone' => '0801003000',
        ])
            ->assertAccepted()
            ->assertJsonPath('status', 'submitted');

        $requestId = (string) DB::table('customer_password_reset_requests')
            ->where('tenant_id', 'ten_pwd')
            ->where('customer_id', 'cus_pwd')
            ->value('id');
        $this->assertNotSame('', $requestId);

        $admin = $this->createTenantSession(
            'ten_pwd',
            'par_pwd',
            ['customer_password_reset.view', 'customer_password_reset.manage'],
            'adm_pwd',
            'pwd-admin@example.test',
        );

        $this->withToken($admin['access_token'])
            ->getJson('http://localhost/api/v1/admin/tenant/password-reset-requests', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_pwd',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $requestId)
            ->assertJsonPath('data.0.customer.phone', '0801003000');

        $issued = $this->withToken($admin['access_token'])
            ->postJson(
                'http://localhost/api/v1/admin/tenant/password-reset-requests/'.$requestId.'/issue-link',
                [],
                [
                    'X-Admin-Scope' => 'tenant',
                    'X-Tenant-Id' => 'ten_pwd',
                    'Idempotency-Key' => 'issue-password-reset-link',
                ],
            )
            ->assertOk()
            ->assertJsonPath('status', 'link_issued')
            ->assertJsonPath('customer.phone', '0801003000')
            ->json();

        $this->assertStringStartsWith('cpr_', $issued['reset_token']);
        $this->assertStringStartsWith('http://password-reset.test/reset-password?token=', $issued['reset_url']);

        $this->postJson('http://password-reset.test/api/v1/customer/auth/password/reset', [
            'token' => $issued['reset_token'],
            'password' => 'new-secret',
            'password_confirmation' => 'new-secret',
        ])
            ->assertOk()
            ->assertJsonPath('status', 'password_reset');

        $this->postJson('http://password-reset.test/api/v1/customer/auth/login', [
            'username' => '0801003000',
            'password' => 'old-secret',
        ])
            ->assertUnauthorized();

        $this->postJson('http://password-reset.test/api/v1/customer/auth/login', [
            'username' => '0801003000',
            'password' => 'new-secret',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', 'cus_pwd');
    }

    public function test_password_reset_returns_service_unavailable_when_storage_is_not_migrated(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_pwd_missing', 'ten_pwd_missing', 'password-reset-missing.test');
        Schema::dropIfExists('customer_password_reset_requests');

        $this->postJson('http://password-reset-missing.test/api/v1/customer/auth/password/forgot', [
            'phone' => '0801003000',
        ])
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'storage_unavailable')
            ->assertJsonPath('error.details.resource', 'customer_password_reset_requests');
    }
}
