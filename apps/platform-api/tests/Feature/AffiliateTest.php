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
        $this->assertMatchesRegularExpression(
            '/^https:\/\/newpaotang\.local\/\?ref=[A-Za-z0-9]{6}$/',
            $affiliate['referral_url'],
        );

        $program = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-programs', [
                'code' => 'program_m8_api',
                'name' => 'API Program',
            ], $headers + ['Idempotency-Key' => 'program-create-main'])
            ->assertCreated()
            ->assertJsonPath('minimum_payout.amount', 30000)
            ->json();

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliate-programs/'.$program['id'], [
                'minimum_payout' => ['amount' => 45000, 'currency' => 'THB'],
            ], $headers + ['Idempotency-Key' => 'program-update-minimum-payout'])
            ->assertOk()
            ->assertJsonPath('minimum_payout.amount', 45000);

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

        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.registration.completed',
            'action_key' => 'affiliate',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.store_name.submitted',
            'action_key' => 'affiliate',
        ]);

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliates/'.$affiliate['id'], [
                'status' => 'suspended',
            ], $headers + ['Idempotency-Key' => 'affiliate-suspend-main'])
            ->assertOk()
            ->assertJsonPath('status', 'suspended');
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.account.restricted',
            'action_key' => 'affiliate',
        ]);

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliates/'.$affiliate['id'], [
                'status' => 'active',
            ], $headers + ['Idempotency-Key' => 'affiliate-activate-main'])
            ->assertOk()
            ->assertJsonPath('status', 'active');
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.account.activated',
            'action_key' => 'affiliate',
        ]);

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

        DB::table('commission_rules')->insert([
            'id' => 'cmr_affiliate_api_payout',
            'tenant_id' => $world['tenant_id'],
            'affiliate_program_id' => $program['id'],
            'affiliate_account_id' => null,
            'code' => 'affiliate_api_payout_balance',
            'name' => 'Affiliate API payout balance',
            'rule_type' => 'fixed_per_order',
            'amount' => 1000,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('commission_transactions')->insert([
            'id' => 'cmt_affiliate_api_payout',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliate['id'],
            'affiliate_attribution_id' => 'aat_affiliate_api_main',
            'order_id' => $world['order_id'],
            'commission_rule_id' => 'cmr_affiliate_api_payout',
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => 'approved',
            'amount' => 1000,
            'currency' => 'THB',
            'idempotency_key' => 'affiliate-api-payout-balance',
            'payload_hash' => hash('sha256', 'affiliate-api-payout-balance'),
            'calculated_at' => now(),
            'approved_by_admin_id' => null,
            'approved_at' => now(),
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

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
