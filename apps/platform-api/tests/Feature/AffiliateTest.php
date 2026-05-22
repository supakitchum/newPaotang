<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AffiliateTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Affiliate_program_link_attribution_and_payout_endpoints_enforce_scope_and_idempotency(): void
    {
        $world = $this->prepareM8World('affiliate-main');
        $admin = $this->m8TenantAdmin($world, [
            'affiliate.view',
            'affiliate.create',
            'affiliate.update',
            'affiliate_program.view',
            'affiliate_program.manage',
            'affiliate_link.view',
            'affiliate_link.manage',
            'affiliate_attribution.view',
            'payout.manage',
        ], 'affiliate-manager');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];

        $affiliate = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliates', [
                'code' => 'aff_m8_api',
                'name' => 'API Affiliate',
                'customer_id' => $world['customer_id'],
            ], $headers + ['Idempotency-Key' => 'affiliate-create-main'])
            ->assertCreated()
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('customer_id', $world['customer_id'])
            ->json();

        $this->assertMatchesRegularExpression('/^[A-Za-z0-9]{6}$/', $affiliate['code']);
        $this->assertNotSame('aff_m8_api', $affiliate['code']);
        $this->assertSame('https://newpaotang.local/?ref='.$affiliate['code'], $affiliate['referral_url']);

        $program = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-programs', [
                'code' => 'program_m8_api',
                'name' => 'API Program',
            ], $headers + ['Idempotency-Key' => 'program-create-main'])
            ->assertCreated()
            ->json();

        $link = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-links', [
                'affiliate_id' => $affiliate['id'],
                'affiliate_program_id' => $program['id'],
                'code' => 'api-link',
            ], $headers + ['Idempotency-Key' => 'link-create-main'])
            ->assertCreated()
            ->assertJsonPath('affiliate_id', $affiliate['id'])
            ->json();

        $this->assertMatchesRegularExpression('/^[A-Za-z0-9]{6}$/', $link['code']);
        $this->assertNotSame('api-link', $link['code']);
        $this->assertSame('https://newpaotang.local/?ref='.$link['code'], $link['url']);
        $this->assertSame($link['url'], $link['canonical_url']);

        DB::table('affiliate_attributions')->insert([
            'id' => 'aat_affiliate_api_main',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliate['id'],
            'affiliate_link_id' => $link['id'],
            'affiliate_program_id' => $program['id'],
            'customer_id' => $world['customer_id'],
            'order_id' => null,
            'status' => 'pending',
            'attributed_at' => now(),
            'converted_at' => null,
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-attributions?affiliate_id='.$affiliate['id'], $headers)
            ->assertOk()
            ->assertJsonPath('data.0.affiliate_id', $affiliate['id']);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliate['id'],
                'amount' => ['amount' => 500, 'currency' => 'THB'],
                'payout_method' => 'crypto',
            ], $headers + ['Idempotency-Key' => 'payout-invalid-method'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.payout_method.0', 'The payout_method field is invalid.');

        $this->assertDatabaseMissing('affiliate_payouts', [
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliate['id'],
            'payout_method' => 'crypto',
        ]);
        $this->assertDatabaseMissing('audit_logs', [
            'tenant_id' => $world['tenant_id'],
            'action' => 'payout.created',
        ]);
        $this->assertDatabaseMissing('idempotency_keys', [
            'tenant_id' => $world['tenant_id'],
            'route_key' => 'admin.tenant.payouts.store',
            'idempotency_key' => 'payout-invalid-method',
        ]);

        $payout = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliate['id'],
                'amount' => ['amount' => 500, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
                'bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_number' => '1234567890',
                ],
            ], $headers + ['Idempotency-Key' => 'payout-create-main', 'X-Request-Id' => 'req-payout-main'])
            ->assertCreated()
            ->assertJsonPath('status', 'pending')
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$payout['id'].'/approve', [
                'reason' => 'approved by ops',
            ], $headers + ['Idempotency-Key' => 'payout-approve-main'])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->withToken($admin['access_token'])
            ->deleteJson('/api/v1/admin/tenant/affiliate-links/'.$link['id'], [], $headers + ['Idempotency-Key' => 'link-archive-main'])
            ->assertNoContent();

        $auditPayload = DB::table('audit_logs')
            ->where('tenant_id', $world['tenant_id'])
            ->where('action', 'payout.created')
            ->value('payload_redacted_json');

        $this->assertStringContainsString('[REDACTED]', (string) $auditPayload);
    }
}
