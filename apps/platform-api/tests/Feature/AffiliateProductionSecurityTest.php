<?php

namespace Tests\Feature;

use App\Modules\Commerce\Services\WalletPostingService;
use App\Modules\Growth\Services\AffiliateTierService;
use App\Modules\Growth\Services\GrowthService;
use App\Support\EncryptedJsonPayload;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use RuntimeException;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AffiliateProductionSecurityTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_affiliate_owner_cannot_apply_or_earn_from_self_referral(): void
    {
        $this->seedDefaultRbac();
        $tenantId = 'ten_aff_self_referral';
        $host = 'affiliate-self-referral.test';
        $customerId = 'cus_aff_self_referral';
        $this->insertActivePartnerTenantWithDomain('par_aff_self_referral', $tenantId, $host);
        $token = $this->issueCustomerToken($tenantId, $customerId);

        $registered = $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', [
                'name' => 'Self Referral Store',
            ], ['Idempotency-Key' => 'affiliate-self-register'])
            ->assertCreated()
            ->json();

        $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', [
                'ref' => $registered['affiliate']['code'],
            ], ['Idempotency-Key' => 'affiliate-self-apply'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.ref.0',
                'An Affiliate referral cannot be applied to its owner.',
            );

        $this->assertDatabaseMissing('affiliate_attributions', [
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'status' => 'pending',
        ]);
    }

    public function test_affiliate_public_and_customer_writes_are_rate_limited(): void
    {
        $this->seedDefaultRbac();
        $tenantId = 'ten_aff_rate_limit';
        $host = 'affiliate-rate-limit.test';
        $customerId = 'cus_aff_rate_limit';
        $this->insertActivePartnerTenantWithDomain('par_aff_rate_limit', $tenantId, $host);
        $token = $this->issueCustomerToken($tenantId, $customerId);
        config()->set('affiliate.rate_limits.public_referral_clicks_per_minute', 1);
        config()->set('affiliate.rate_limits.customer_writes_per_minute', 1);
        RateLimiter::clear(hash('sha256', strtolower($host).'|127.0.0.1'));

        $registered = $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])
            ->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', [
                'name' => 'Rate Limited Affiliate',
            ], ['Idempotency-Key' => 'affiliate-rate-limit-register'])
            ->assertCreated()
            ->json();

        $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])
            ->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/store-name-requests', [
                'name' => 'Rate Limited Affiliate Updated',
            ], ['Idempotency-Key' => 'affiliate-rate-limit-write'])
            ->assertStatus(429);

        $referral = $registered['links'][0]['code'];
        $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])
            ->postJson('http://'.$host.'/api/v1/public/affiliate/referrals/click', [
                'ref' => $referral,
                'visitor_id' => 'affiliate-rate-limit-visitor',
            ])
            ->assertCreated();

        $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])
            ->postJson('http://'.$host.'/api/v1/public/affiliate/referrals/click', [
                'ref' => $referral,
                'visitor_id' => 'affiliate-rate-limit-visitor-second',
            ])
            ->assertStatus(429);
    }

    public function test_affiliate_admin_and_customer_endpoints_enforce_permissions_and_tenant_scope(): void
    {
        $this->seedDefaultRbac();
        $firstTenantId = 'ten_aff_scope_first';
        $secondTenantId = 'ten_aff_scope_second';
        $firstHost = 'affiliate-scope-first.test';
        $secondHost = 'affiliate-scope-second.test';
        $this->insertActivePartnerTenantWithDomain('par_aff_scope_first', $firstTenantId, $firstHost);
        $this->insertActivePartnerTenantWithDomain('par_aff_scope_second', $secondTenantId, $secondHost);
        $customerToken = $this->issueCustomerToken($firstTenantId, 'cus_aff_scope_first');
        $unprivileged = $this->createTenantSession(
            $firstTenantId,
            'par_aff_scope_first',
            [],
            'adm_aff_scope_unprivileged',
            'affiliate-scope-unprivileged@example.test',
        );
        $tierViewer = $this->createTenantSession(
            $firstTenantId,
            'par_aff_scope_first',
            ['affiliate_tier.view'],
            'adm_aff_scope_viewer',
            'affiliate-scope-viewer@example.test',
        );

        $this->withToken($unprivileged['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-tiers', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $firstTenantId,
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($unprivileged['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', [
                'name' => 'Unauthorized Campaign',
                'campaign_type' => 'fixed_threshold',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $firstTenantId,
                'Idempotency-Key' => 'affiliate-scope-unauthorized-campaign',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tierViewer['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-tiers', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $secondTenantId,
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($customerToken)
            ->getJson('http://'.$secondHost.'/api/v1/customer/affiliate')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->assertDatabaseMissing('affiliate_tier_campaigns', [
            'tenant_id' => $firstTenantId,
            'name' => 'Unauthorized Campaign',
        ]);
    }

    public function test_payout_balance_is_reserved_and_rejection_releases_it(): void
    {
        $world = $this->prepareM8World('affiliate-secure-payout');
        $tiers = app(AffiliateTierService::class)->ensureTenantTiers($world['tenant_id']);
        $affiliateId = 'aff_secure_payout';
        $now = now();
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'affiliate_program_id' => $tiers['bronze']->id,
            'code' => 'Ps1A2B',
            'name' => 'Secure Payout Store',
            'store_name_status' => 'approved',
            'store_name_normalized' => 'secure payout store',
            'store_name_approved_at' => $now,
            'store_name_change_available_at' => $now->copy()->addMonthsNoOverflow(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $ruleId = (string) DB::table('commission_rules')
            ->where('tenant_id', $world['tenant_id'])
            ->where('affiliate_program_id', $tiers['bronze']->id)
            ->where('rule_type', 'per_ticket')
            ->value('id');
        DB::table('commission_transactions')->insert([
            'id' => 'cmt_secure_payout',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_attribution_id' => null,
            'order_id' => $world['order_id'],
            'commission_rule_id' => $ruleId,
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => 'approved',
            'amount' => 1000,
            'ticket_count' => 1,
            'tier_code' => 'bronze',
            'commission_per_ticket_amount' => 1000,
            'currency' => 'THB',
            'idempotency_key' => 'secure-payout-balance',
            'payload_hash' => hash('sha256', 'secure-payout-balance'),
            'calculated_at' => $now,
            'approved_by_admin_id' => null,
            'approved_at' => $now,
            'metadata_json' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $admin = $this->m8TenantAdmin($world, ['payout.manage'], 'secure-payout');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];
        $bankAccount = [
            'bank_name' => 'Production Test Bank',
            'account_name' => 'Secure Affiliate',
            'account_number' => '1234567890',
        ];

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => '6e2', 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
            ], $headers + ['Idempotency-Key' => 'secure-payout-ambiguous-amount'])
            ->assertUnprocessable()
            ->assertJsonFragment([
                'amount.amount' => ['The amount.amount field must be a whole minor-unit amount.'],
            ]);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 600, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
            ], $headers + ['Idempotency-Key' => 'secure-payout-missing-bank'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.bank_account.0',
                'A bank name and account number are required for a bank transfer payout.',
            );

        $first = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 600, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
                'bank_account' => $bankAccount,
            ], $headers + ['Idempotency-Key' => 'secure-payout-first'])
            ->assertCreated()
            ->assertJsonPath('bank_account.account_number', '1234567890')
            ->json();
        $storedBankSnapshot = DB::table('affiliate_payouts')->where('id', $first['id'])->first([
            'bank_account_json',
            'bank_account_encrypted',
        ]);
        $this->assertNull($storedBankSnapshot->bank_account_json);
        $this->assertStringNotContainsString(
            '1234567890',
            (string) $storedBankSnapshot->bank_account_encrypted,
        );
        $this->assertSame(
            $bankAccount,
            EncryptedJsonPayload::decrypt($storedBankSnapshot->bank_account_encrypted),
        );

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 500, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
                'bank_account' => $bankAccount,
            ], $headers + ['Idempotency-Key' => 'secure-payout-overdraw'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.amount.0',
                'The amount field exceeds available affiliate balance.',
            );

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$first['id'].'/reject', [
                'reason' => 'Bank account could not be verified.',
            ], $headers + ['Idempotency-Key' => 'secure-payout-reject'])
            ->assertOk()
            ->assertJsonPath('status', 'rejected');

        $second = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 500, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
                'bank_account' => $bankAccount,
            ], $headers + ['Idempotency-Key' => 'secure-payout-after-reject'])
            ->assertCreated()
            ->assertJsonPath('status', 'pending')
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$second['id'].'/approve', [
                'reason' => 'Bank account verified.',
            ], $headers + ['Idempotency-Key' => 'secure-payout-approve-bank'])
            ->assertOk()
            ->assertJsonPath('status', 'approved')
            ->assertJsonPath('paid_at', null);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$second['id'].'/pay', [], $headers + [
                'Idempotency-Key' => 'secure-payout-pay-missing-reference',
            ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.payment_reference.0',
                'The payment_reference field is required.',
            );

        $paid = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$second['id'].'/pay', [
                'payment_reference' => 'BANK-TXN-20260724-001',
                'reason' => 'Bank transfer completed.',
            ], $headers + ['Idempotency-Key' => 'secure-payout-pay-bank'])
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('payment_reference', 'BANK-TXN-20260724-001')
            ->json();

        $this->assertNotNull($paid['paid_at']);
        $this->assertNull($paid['payout_ledger_id']);
        $paidAudit = DB::table('audit_logs')
            ->where('action', 'payout.paid')
            ->where('target_id', $second['id'])
            ->latest('created_at')
            ->first();
        $this->assertNotNull($paidAudit);
        $paidAuditPayload = json_decode(
            (string) $paidAudit->payload_redacted_json,
            true,
            flags: JSON_THROW_ON_ERROR,
        );
        $this->assertSame('[REDACTED]', $paidAuditPayload['payment_reference']);
        $this->assertStringNotContainsString(
            'BANK-TXN-20260724-001',
            (string) $paidAudit->payload_redacted_json,
        );
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$second['id'].'/pay', [
                'payment_reference' => 'BANK-TXN-20260724-001',
            ], $headers + ['Idempotency-Key' => 'secure-payout-pay-bank-retry'])
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('paid_at', $paid['paid_at']);

        $third = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 400, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
                'bank_account' => $bankAccount,
            ], $headers + ['Idempotency-Key' => 'secure-payout-third'])
            ->assertCreated()
            ->json();
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$third['id'].'/approve', [], $headers + [
                'Idempotency-Key' => 'secure-payout-third-approve',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$third['id'].'/pay', [
                'payment_reference' => 'BANK-TXN-20260724-001',
            ], $headers + ['Idempotency-Key' => 'secure-payout-third-duplicate-reference'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.payment_reference.0',
                'The payment_reference has already been used for another payout.',
            );

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 100, 'currency' => 'USD'],
                'payout_method' => 'bank_transfer',
                'bank_account' => $bankAccount,
            ], $headers + ['Idempotency-Key' => 'secure-payout-currency'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.amount.0',
                'The payout currency must match the Affiliate account currency.',
            );
    }

    public function test_wallet_credit_payout_posts_once_and_keeps_auditable_payment_evidence(): void
    {
        $world = $this->prepareM8World('affiliate-wallet-credit');
        $tiers = app(AffiliateTierService::class)->ensureTenantTiers($world['tenant_id']);
        $affiliateId = 'aff_wallet_credit';
        $now = now();
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'affiliate_program_id' => $tiers['bronze']->id,
            'code' => 'Wc1A2B',
            'name' => 'Wallet Credit Store',
            'store_name_status' => 'approved',
            'store_name_normalized' => 'wallet credit store',
            'store_name_approved_at' => $now,
            'store_name_change_available_at' => $now->copy()->addMonthsNoOverflow(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $ruleId = (string) DB::table('commission_rules')
            ->where('tenant_id', $world['tenant_id'])
            ->where('affiliate_program_id', $tiers['bronze']->id)
            ->where('rule_type', 'per_ticket')
            ->value('id');
        DB::table('commission_transactions')->insert([
            'id' => 'cmt_wallet_credit',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_attribution_id' => null,
            'order_id' => $world['order_id'],
            'commission_rule_id' => $ruleId,
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => 'approved',
            'amount' => 1000,
            'ticket_count' => 1,
            'tier_code' => 'bronze',
            'commission_per_ticket_amount' => 1000,
            'currency' => 'THB',
            'idempotency_key' => 'wallet-credit-commission',
            'payload_hash' => hash('sha256', 'wallet-credit-commission'),
            'calculated_at' => $now,
            'approved_by_admin_id' => null,
            'approved_at' => $now,
            'metadata_json' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $admin = $this->m8TenantAdmin($world, ['payout.manage'], 'wallet-credit');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];
        $payout = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts', [
                'affiliate_id' => $affiliateId,
                'amount' => ['amount' => 600, 'currency' => 'THB'],
                'payout_method' => 'wallet_credit',
            ], $headers + ['Idempotency-Key' => 'wallet-credit-create'])
            ->assertCreated()
            ->assertJsonPath('status', 'pending')
            ->json();

        $paid = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$payout['id'].'/approve', [
                'reason' => 'Credit Affiliate commission to wallet.',
            ], $headers + [
                'Idempotency-Key' => 'wallet-credit-approve-first',
                'X-Request-Id' => 'req-wallet-credit-first',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('amount.amount', 600)
            ->json();

        $this->assertNotEmpty($paid['wallet_id']);
        $this->assertNotEmpty($paid['payout_ledger_id']);
        $this->assertSame($paid['payout_ledger_id'], $paid['payment_reference']);
        $this->assertNotNull($paid['approved_at']);
        $this->assertNotNull($paid['paid_at']);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$payout['id'].'/approve', [
                'reason' => 'A second operator retry must not credit again.',
            ], $headers + ['Idempotency-Key' => 'wallet-credit-approve-second'])
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('payout_ledger_id', $paid['payout_ledger_id']);

        $this->assertSame(1, DB::table('wallet_ledger')
            ->where('tenant_id', $world['tenant_id'])
            ->where('reference_type', 'affiliate_payout')
            ->where('reference_id', $payout['id'])
            ->count());
        $this->assertDatabaseHas('wallet_ledger', [
            'id' => $paid['payout_ledger_id'],
            'wallet_id' => $paid['wallet_id'],
            'customer_id' => $world['customer_id'],
            'entry_type' => 'credit',
            'status' => 'posted',
            'amount' => 600,
            'idempotency_key' => 'affiliate-payout:'.$payout['id'],
        ]);
        $this->assertDatabaseHas('wallets', [
            'id' => $paid['wallet_id'],
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'balance_amount' => 600,
        ]);
        $this->assertDatabaseHas('affiliate_payouts', [
            'id' => $payout['id'],
            'status' => 'paid',
            'wallet_id' => $paid['wallet_id'],
            'payout_ledger_id' => $paid['payout_ledger_id'],
            'paid_by_admin_id' => $admin['user']['id'],
        ]);
        $this->assertSame(1, DB::table('sync_outbox')
            ->where('producer', 'affiliate_payout')
            ->where('idempotency_key', 'affiliate-payout:'.$payout['id'])
            ->count());
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $world['tenant_id'],
            'event_key' => 'affiliate.payout.paid',
            'subject_id' => $payout['id'],
        ]);

        $posting = app(WalletPostingService::class);
        $standalone = $posting->post(
            $world['tenant_id'],
            $paid['wallet_id'],
            $world['customer_id'],
            'credit',
            50,
            'security_probe',
            'wallet-posting-standalone',
            'wallet-posting-standalone',
            $admin['user']['id'],
        );
        $replayed = $posting->post(
            $world['tenant_id'],
            $paid['wallet_id'],
            $world['customer_id'],
            'credit',
            50,
            'security_probe',
            'wallet-posting-standalone',
            'wallet-posting-standalone',
            $admin['user']['id'],
        );
        $this->assertSame($standalone, $replayed);
        $this->assertDatabaseHas('wallets', [
            'id' => $paid['wallet_id'],
            'balance_amount' => 650,
        ]);
        try {
            $posting->post(
                $world['tenant_id'],
                $paid['wallet_id'],
                $world['customer_id'],
                'credit',
                51,
                'security_probe',
                'wallet-posting-standalone',
                'wallet-posting-standalone',
                $admin['user']['id'],
            );
            $this->fail('A reused wallet idempotency key with a changed amount must fail.');
        } catch (RuntimeException $exception) {
            $this->assertSame('wallet_ledger_idempotency_conflict', $exception->getMessage());
        }
        $this->assertDatabaseHas('wallets', [
            'id' => $paid['wallet_id'],
            'balance_amount' => 650,
        ]);
        foreach ([
            ['entry_type' => 'credit', 'amount' => -50, 'idempotency_key' => 'wallet-posting-negative-credit'],
            ['entry_type' => 'unknown', 'amount' => 50, 'idempotency_key' => 'wallet-posting-unknown-entry'],
        ] as $invalidPosting) {
            try {
                $posting->post(
                    $world['tenant_id'],
                    $paid['wallet_id'],
                    $world['customer_id'],
                    $invalidPosting['entry_type'],
                    $invalidPosting['amount'],
                    'security_probe',
                    $invalidPosting['idempotency_key'],
                    $invalidPosting['idempotency_key'],
                    $admin['user']['id'],
                );
                $this->fail('Invalid wallet posting semantics must fail before writing a ledger entry.');
            } catch (RuntimeException $exception) {
                $this->assertSame('wallet_ledger_invalid_post', $exception->getMessage());
            }
            $this->assertDatabaseMissing('wallet_ledger', [
                'tenant_id' => $world['tenant_id'],
                'idempotency_key' => $invalidPosting['idempotency_key'],
            ]);
        }

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/payouts/'.$payout['id'].'/reject', [
                'reason' => 'Paid payouts cannot be rejected.',
            ], $headers + ['Idempotency-Key' => 'wallet-credit-reject-paid'])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');
    }

    public function test_delayed_commission_uses_rate_effective_when_order_was_paid(): void
    {
        $world = $this->prepareM8World('affiliate-rate-snapshot');
        $tiers = app(AffiliateTierService::class)->ensureTenantTiers($world['tenant_id']);
        $paidAt = now()->subHour();
        DB::table('orders')->where('id', $world['order_id'])->update([
            'paid_at' => $paidAt,
            'updated_at' => now(),
        ]);
        $ownerId = 'cus_affiliate_rate_owner';
        $this->issueCustomerToken($world['tenant_id'], $ownerId);
        $affiliateId = 'aff_rate_snapshot';
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $ownerId,
            'affiliate_program_id' => $tiers['bronze']->id,
            'code' => 'Rt1A2B',
            'name' => 'Rate Snapshot Store',
            'store_name_status' => 'approved',
            'store_name_normalized' => 'rate snapshot store',
            'store_name_approved_at' => now()->subDay(),
            'store_name_change_available_at' => now()->addMonths(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now()->subDay(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_attributions')->insert([
            'id' => 'aat_rate_snapshot',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_link_id' => null,
            'affiliate_program_id' => $tiers['bronze']->id,
            'customer_id' => $world['customer_id'],
            'order_id' => null,
            'status' => 'pending',
            'attributed_at' => now()->subHours(2),
            'converted_at' => null,
            'metadata_json' => json_encode(['expires_at' => now()->addDay()->toISOString()], JSON_THROW_ON_ERROR),
            'created_at' => now()->subHours(2),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_tier_rate_history')
            ->where('tenant_id', $world['tenant_id'])
            ->where('affiliate_program_id', $tiers['bronze']->id)
            ->delete();
        DB::table('affiliate_tier_rate_history')->insert([
            'id' => 'atrh_rate_snapshot_old',
            'tenant_id' => $world['tenant_id'],
            'affiliate_program_id' => $tiers['bronze']->id,
            'commission_per_ticket_amount' => 100,
            'source' => 'test',
            'metadata_json' => null,
            'effective_at' => now()->subDay(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_programs')->where('id', $tiers['bronze']->id)->update([
            'commission_per_ticket_amount' => 900,
            'updated_at' => now(),
        ]);
        DB::table('commission_rules')
            ->where('tenant_id', $world['tenant_id'])
            ->where('affiliate_program_id', $tiers['bronze']->id)
            ->where('rule_type', 'per_ticket')
            ->update(['amount' => 900, 'updated_at' => now()]);
        DB::table('affiliate_tier_rate_history')->insert([
            'id' => 'atrh_rate_snapshot_new',
            'tenant_id' => $world['tenant_id'],
            'affiliate_program_id' => $tiers['bronze']->id,
            'commission_per_ticket_amount' => 900,
            'source' => 'test',
            'metadata_json' => null,
            'effective_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $growth = app(GrowthService::class);
        $this->assertSame('aat_rate_snapshot', $growth->bindAffiliateAttributionToPaidOrder(
            $world['order_id'],
            $world['tenant_id'],
        ));
        $this->assertSame(1, $growth->calculateCommissions(
            $world['order_id'],
            $world['tenant_id'],
            1,
        ));
        $this->assertDatabaseHas('commission_transactions', [
            'tenant_id' => $world['tenant_id'],
            'order_id' => $world['order_id'],
            'affiliate_account_id' => $affiliateId,
            'amount' => 100,
            'ticket_count' => 1,
            'tier_code' => 'bronze',
            'commission_per_ticket_amount' => 100,
        ]);
    }

    public function test_campaign_counts_paid_order_with_bound_pending_attribution(): void
    {
        $world = $this->prepareM8World('affiliate-campaign-pending');
        $tiers = app(AffiliateTierService::class)->ensureTenantTiers($world['tenant_id']);
        $ownerId = 'cus_campaign_pending_owner';
        $this->issueCustomerToken($world['tenant_id'], $ownerId);
        $affiliateId = 'aff_campaign_pending';
        $campaignId = 'atc_campaign_pending';
        $paidAt = now()->subHour();
        DB::table('orders')->where('id', $world['order_id'])->update([
            'paid_at' => $paidAt,
            'updated_at' => now(),
        ]);
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $ownerId,
            'affiliate_program_id' => $tiers['bronze']->id,
            'code' => 'Cp1A2B',
            'name' => 'Campaign Pending Store',
            'store_name_status' => 'approved',
            'store_name_normalized' => 'campaign pending store',
            'store_name_approved_at' => now()->subDay(),
            'store_name_change_available_at' => now()->addMonths(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now()->subDay(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_attributions')->insert([
            'id' => 'aat_campaign_pending',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_link_id' => null,
            'affiliate_program_id' => $tiers['bronze']->id,
            'customer_id' => $world['customer_id'],
            'order_id' => $world['order_id'],
            'status' => 'pending',
            'attributed_at' => now()->subHours(2),
            'converted_at' => null,
            'metadata_json' => null,
            'created_at' => now()->subHours(2),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_tier_campaigns')->insert([
            'id' => $campaignId,
            'tenant_id' => $world['tenant_id'],
            'name' => 'Pending attribution reconciliation',
            'campaign_type' => 'fixed_threshold',
            'status' => 'active',
            'starts_at' => now()->subHours(2),
            'ends_at' => now()->subMinute(),
            'finalized_at' => null,
            'created_by_admin_id' => null,
            'finalized_by_admin_id' => null,
            'metadata_json' => null,
            'created_at' => now()->subHours(3),
            'updated_at' => now(),
        ]);
        foreach ([
            ['id' => 'acr_campaign_pending_0', 'count' => 0, 'program' => $tiers['bronze']->id, 'order' => 0],
            ['id' => 'acr_campaign_pending_1', 'count' => 1, 'program' => $tiers['silver']->id, 'order' => 1],
        ] as $rule) {
            DB::table('affiliate_tier_campaign_rules')->insert([
                'id' => $rule['id'],
                'tenant_id' => $world['tenant_id'],
                'campaign_id' => $campaignId,
                'target_program_id' => $rule['program'],
                'rule_order' => $rule['order'],
                'minimum_ticket_count' => $rule['count'],
                'rank_from' => null,
                'rank_to' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $result = app(AffiliateTierService::class)->finalizeCampaign(
            $world['tenant_id'],
            $campaignId,
        );
        $this->assertNull($result['error'] ?? null);
        $this->assertDatabaseHas('affiliate_tier_campaign_results', [
            'campaign_id' => $campaignId,
            'affiliate_account_id' => $affiliateId,
            'ticket_count' => 1,
            'applied_program_id' => $tiers['silver']->id,
        ]);
        $this->assertDatabaseHas('affiliate_accounts', [
            'id' => $affiliateId,
            'affiliate_program_id' => $tiers['silver']->id,
        ]);
    }
}
