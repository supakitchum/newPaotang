<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerSupportSessionTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    private string $tenantId = 'ten_support_session';

    private string $host = 'support-session.test';

    protected function setUp(): void
    {
        parent::setUp();

        $key = openssl_pkey_new([
            'digest_alg' => 'sha256',
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);
        $privateKey = '';
        openssl_pkey_export($key, $privateKey);
        config([
            'support.api_url' => 'https://support.example.test/v1',
            'support.realtime_url' => 'wss://support.example.test/app',
            'support.jwt.private_key' => $privateKey,
            'support.jwt.private_key_path' => null,
            'support.jwt.ttl_seconds' => 600,
        ]);

        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_support_session',
            $this->tenantId,
            $this->host,
        );
        DB::table('partner_tenant_feature_flags')->insert([
            'id' => 'pff_support_session',
            'tenant_id' => $this->tenantId,
            'feature_key' => 'customer_support',
            'enabled' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_customer_support_session_is_tenant_scoped_and_independent_of_agent_availability(): void
    {
        $customerId = 'cus_support_session';
        $token = $this->issueCustomerToken($this->tenantId, $customerId);

        $response = $this->withToken($token)
            ->postJson('http://'.$this->host.'/api/v1/customer/support-session')
            ->assertOk()
            ->assertJsonPath('api_url', 'https://support.example.test/v1')
            ->assertJsonPath('realtime.url', 'wss://support.example.test/app')
            ->assertJsonPath(
                'realtime.channels.0',
                'private-support.tenant.'.$this->tenantId.'.customer.'.$customerId,
            )
            ->json();
        $claims = $this->claims((string) $response['token']);
        $this->assertSame($customerId, $claims['sub']);
        $this->assertSame($this->tenantId, $claims['tenant_id']);
        $this->assertSame('customer', $claims['actor_type']);
        $this->assertSame([], $claims['permissions']);
        $this->assertSame(600, $claims['exp'] - $claims['iat']);

        DB::table('partner_tenant_feature_flags')
            ->where('tenant_id', $this->tenantId)
            ->where('feature_key', 'customer_support')
            ->update(['enabled' => false, 'updated_at' => now()]);

        $this->withToken($token)
            ->postJson('http://'.$this->host.'/api/v1/customer/support-session')
            ->assertOk()
            ->assertJsonPath('api_url', 'https://support.example.test/v1');
    }

    public function test_admin_support_session_contains_only_granted_support_permissions(): void
    {
        $support = $this->createTenantSession(
            $this->tenantId,
            'par_support_session',
            [
                'support_ticket.view_assigned',
                'support_ticket.reply_assigned',
                'dashboard.view',
            ],
            'adm_support_session',
            'support-session@example.test',
        );
        $master = $this->createTenantSession(
            $this->tenantId,
            'par_support_session',
            [
                'support_ticket.view_all',
                'support_ticket.assign',
                'support_agent.manage',
                'support_faq.manage',
                'support_report.view',
            ],
            'adm_master_support_session',
            'master-support-session@example.test',
        );
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $this->tenantId,
        ];
        DB::table('partner_tenant_feature_flags')
            ->where('tenant_id', $this->tenantId)
            ->where('feature_key', 'customer_support')
            ->update(['enabled' => false, 'updated_at' => now()]);

        $supportResponse = $this->withToken($support['access_token'])
            ->postJson('/api/v1/admin/tenant/support-session', [], $headers)
            ->assertOk()
            ->assertJsonCount(1, 'realtime.channels')
            ->json();
        $this->assertSame([
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
        ], $this->claims((string) $supportResponse['token'])['permissions']);

        $masterResponse = $this->withToken($master['access_token'])
            ->postJson('/api/v1/admin/tenant/support-session', [], $headers)
            ->assertOk()
            ->assertJsonPath(
                'realtime.channels.1',
                'private-support.tenant.'.$this->tenantId.'.queue',
            )
            ->json();
        $this->assertSame([
            'support_ticket.view_all',
            'support_ticket.assign',
            'support_agent.manage',
            'support_faq.manage',
            'support_report.view',
        ], $this->claims((string) $masterResponse['token'])['permissions']);
    }

    /**
     * @return array<string, mixed>
     */
    private function claims(string $token): array
    {
        $parts = explode('.', $token);
        $this->assertCount(3, $parts);
        $payload = $parts[1];
        $padding = strlen($payload) % 4;
        if ($padding !== 0) {
            $payload .= str_repeat('=', 4 - $padding);
        }

        return json_decode(
            base64_decode(strtr($payload, '-_', '+/'), true),
            true,
            flags: JSON_THROW_ON_ERROR,
        );
    }
}
