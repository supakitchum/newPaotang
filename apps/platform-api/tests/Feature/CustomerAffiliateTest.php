<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerAffiliateTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_Customer_affiliate_self_service_registers_with_customer_id_and_requests_payout(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_customer_affiliate';
        $tenantId = 'ten_customer_affiliate';
        $host = 'customer-affiliate.test';
        $customerId = 'cus_customer_affiliate';
        $this->insertActivePartnerTenantWithDomain($partnerId, $tenantId, $host);
        $token = $this->issueCustomerToken($tenantId, $customerId);

        $this->withToken($token)
            ->patchJson('http://'.$host.'/api/v1/customer/profile', [
                'reward_payout_bank_account' => [
                    'bank_name' => 'Example Bank',
                    'account_name' => 'Customer Affiliate',
                    'account_number' => '1234567890',
                ],
                'pin' => '246810',
            ], [
                'Idempotency-Key' => 'customer-affiliate-bank-profile',
            ])
            ->assertOk()
            ->assertJsonPath('reward_payout_bank_account.bank_name', 'Example Bank');

        $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', [], [
                'Idempotency-Key' => 'customer-affiliate-register-no-store',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.name.0', 'The store name field is required for affiliate accounts.');

        $registered = $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', [
                'code' => 'lucky customer',
                'name' => 'Lucky Customer Shop',
            ], [
                'Idempotency-Key' => 'customer-affiliate-register',
            ])
            ->assertCreated()
            ->assertJsonPath('is_affiliate', true)
            ->assertJsonPath('affiliate.customer_id', $customerId)
            ->assertJsonPath('affiliate.name', 'Lucky Customer Shop')
            ->assertJsonPath('profile.reward_payout_bank_account.account_number', '1234567890')
            ->assertJsonPath('payout_policy.minimum_payout.amount', 30000)
            ->json();

        $affiliateId = $registered['affiliate']['id'];
        $this->assertMatchesRegularExpression('/^[A-Za-z0-9]{6}$/', $registered['affiliate']['code']);
        $this->assertNotSame('lucky_customer', $registered['affiliate']['code']);
        $this->assertMatchesRegularExpression('/^[A-Za-z0-9]{6}$/', $registered['links'][0]['code'] ?? '');
        $this->assertSame('https://'.$host.'/?ref='.$registered['links'][0]['code'], $registered['links'][0]['url']);
        $this->assertSame($registered['links'][0]['url'], $registered['affiliate']['canonical_url']);
        $this->assertSame($registered['links'][0]['id'], $registered['affiliate']['primary_link']['id']);

        $gameId = 'gam_customer_affiliate';
        $reservationId = 'res_customer_affiliate';
        $orderId = 'ord_customer_affiliate';
        $ruleId = 'cmr_customer_affiliate';
        $commissionId = 'cmt_customer_affiliate';
        $this->insertGame($gameId, 'open');
        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => now()->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => now(),
            'idempotency_key' => 'reserve-aff-customer',
            'payload_hash' => hash('sha256', 'reserve-aff-customer'),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 10000,
            'currency' => 'THB',
            'reference' => 'AFF-CUSTOMER',
            'admin_note' => null,
            'idempotency_key' => 'order-aff-customer',
            'payload_hash' => hash('sha256', 'order-aff-customer'),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('commission_rules')->insert([
            'id' => $ruleId,
            'tenant_id' => $tenantId,
            'affiliate_program_id' => null,
            'affiliate_account_id' => $affiliateId,
            'code' => 'customer_affiliate_rule',
            'name' => 'Customer Affiliate Rule',
            'rule_type' => 'fixed_per_order',
            'amount' => 30000,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('commission_transactions')->insert([
            'id' => $commissionId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliateId,
            'affiliate_attribution_id' => null,
            'order_id' => $orderId,
            'commission_rule_id' => $ruleId,
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => 'approved',
            'amount' => 30000,
            'currency' => 'THB',
            'idempotency_key' => 'commission-aff-customer',
            'payload_hash' => hash('sha256', 'commission-aff-customer'),
            'calculated_at' => now(),
            'approved_by_admin_id' => null,
            'approved_at' => now(),
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($token)
            ->getJson('http://'.$host.'/api/v1/customer/affiliate')
            ->assertOk()
            ->assertJsonPath('stats.available_balance.amount', 30000)
            ->assertJsonPath('payout_policy.minimum_payout.amount', 30000)
            ->assertJsonPath('commissions.0.id', $commissionId);

        $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/payouts', [
                'amount' => ['amount' => 500, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
            ], [
                'Idempotency-Key' => 'customer-affiliate-payout-too-low',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.amount.0', 'The amount field must be at least the affiliate program minimum payout amount.');

        $this->withToken($token)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/payouts', [
                'amount' => ['amount' => 30000, 'currency' => 'THB'],
                'payout_method' => 'bank_transfer',
            ], [
                'Idempotency-Key' => 'customer-affiliate-payout',
            ])
            ->assertCreated()
            ->assertJsonPath('affiliate_account_id', $affiliateId)
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('amount.amount', 30000)
            ->assertJsonPath('bank_account.bank_name', 'Example Bank')
            ->assertJsonPath('bank_account.account_number', '1234567890');

        $this->withToken($token)
            ->getJson('http://'.$host.'/api/v1/customer/affiliate/payouts')
            ->assertOk()
            ->assertJsonPath('data.0.amount.amount', 30000);
    }

    public function test_Customer_referral_apply_is_tenant_scoped_last_click_and_commission_source(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_referral_apply';
        $tenantId = 'ten_referral_apply';
        $host = 'referral-apply.test';
        $affiliateCustomerId = 'cus_referral_affiliate';
        $buyerId = 'cus_referral_buyer';
        $this->insertActivePartnerTenantWithDomain($partnerId, $tenantId, $host);
        $affiliateToken = $this->issueCustomerToken($tenantId, $affiliateCustomerId);
        $buyerToken = $this->issueCustomerToken($tenantId, $buyerId);

        $registered = $this->withToken($affiliateToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', [
                'name' => 'Referral Apply Shop',
            ], [
                'Idempotency-Key' => 'customer-referral-affiliate-register',
            ])
            ->assertCreated()
            ->json();
        $link = $registered['links'][0];

        $this->postJson('http://'.$host.'/api/v1/public/affiliate/referrals/click', [
            'ref' => $link['code'],
            'visitor_id' => 'visitor-referral-apply',
            'landing_url' => 'https://'.$host.'/?ref='.$link['code'],
        ])
            ->assertCreated()
            ->assertJsonPath('tracked', true)
            ->assertJsonPath('affiliate_account_id', $registered['affiliate']['id']);

        $this->postJson('http://'.$host.'/api/v1/public/affiliate/referrals/click', [
            'ref' => $link['code'],
            'visitor_id' => 'visitor-referral-apply',
            'landing_url' => 'https://'.$host.'/?ref='.$link['code'],
        ])
            ->assertOk()
            ->assertJsonPath('tracked', true);

        $applied = $this->withToken($buyerToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', [
                'ref' => $link['code'],
                'visitor_id' => 'visitor-referral-apply',
                'registered' => true,
            ])
            ->assertCreated()
            ->assertJsonPath('applied', true)
            ->assertJsonPath('attribution.affiliate_account_id', $registered['affiliate']['id'])
            ->assertJsonPath('attribution.affiliate_link_id', $link['id'])
            ->json();

        $attributionId = $applied['attribution']['id'];
        $expiresAt = \Illuminate\Support\Carbon::parse($applied['expires_at']);
        $this->assertTrue($expiresAt->between(now()->addDays(29), now()->addDays(31)));
        $this->assertSame($link['code'], $applied['attribution']['metadata']['ref_code']);
        $this->assertSame('affiliate_link', $applied['attribution']['metadata']['resolved_from']);
        $this->assertDatabaseHas('affiliate_referral_visits', [
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $registered['affiliate']['id'],
            'affiliate_link_id' => $link['id'],
            'visitor_key' => 'visitor-referral-apply',
            'customer_id' => $buyerId,
            'click_count' => 2,
        ]);

        $this->withToken($affiliateToken)
            ->getJson('http://'.$host.'/api/v1/customer/affiliate')
            ->assertOk()
            ->assertJsonPath('stats.visitor_count', 1)
            ->assertJsonPath('stats.registered_count', 1);

        $affiliateList = app(GrowthService::class)->listAffiliateAccounts($tenantId, [
            'sort_by' => 'visitor_count',
            'sort_dir' => 'desc',
        ]);
        $this->assertSame($registered['affiliate']['id'], $affiliateList['data'][0]['id']);
        $this->assertSame('Customer '.$affiliateCustomerId, $affiliateList['data'][0]['customer_name']);
        $this->assertSame(1, $affiliateList['data'][0]['visitor_count']);
        $this->assertSame(1, $affiliateList['data'][0]['registered_count']);

        $this->withToken($buyerToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', [
                'ref' => $registered['affiliate']['code'],
            ])
            ->assertOk()
            ->assertJsonPath('attribution.id', $attributionId)
            ->assertJsonPath('attribution.affiliate_account_id', $registered['affiliate']['id'])
            ->assertJsonPath('attribution.affiliate_link_id', $link['id'])
            ->assertJsonPath('attribution.metadata.resolved_from', 'affiliate_account_primary_link');

        $secondAffiliateCustomerId = 'cus_referral_second_affiliate';
        $this->issueCustomerToken($tenantId, $secondAffiliateCustomerId);
        $secondAffiliateId = 'aff_referral_second';
        $secondCode = 'Aa1Bb2';
        DB::table('affiliate_accounts')->insert([
            'id' => $secondAffiliateId,
            'tenant_id' => $tenantId,
            'customer_id' => $secondAffiliateCustomerId,
            'code' => $secondCode,
            'name' => 'Second Affiliate',
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($buyerToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', [
                'ref' => $secondCode,
            ])
            ->assertOk()
            ->assertJsonPath('attribution.id', $attributionId)
            ->assertJsonPath('attribution.affiliate_account_id', $secondAffiliateId)
            ->assertJsonPath('attribution.affiliate_link_id', null)
            ->assertJsonPath('attribution.metadata.resolved_from', 'affiliate_account');

        $this->assertSame(1, DB::table('affiliate_attributions')->where('tenant_id', $tenantId)->where('customer_id', $buyerId)->where('status', 'pending')->count());

        $inactiveCode = 'Xy9Zz8';
        DB::table('affiliate_accounts')->insert([
            'id' => 'aff_referral_inactive',
            'tenant_id' => $tenantId,
            'customer_id' => null,
            'code' => $inactiveCode,
            'name' => 'Inactive Affiliate',
            'phone' => null,
            'email' => null,
            'status' => 'inactive',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->withToken($buyerToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', ['ref' => $inactiveCode])
            ->assertNotFound();

        $otherTenantId = 'ten_referral_other';
        $this->insertActivePartnerTenantWithDomain('par_referral_other', $otherTenantId, 'referral-other.test');
        DB::table('customers')->insert([
            'id' => 'cus_referral_other_affiliate',
            'tenant_id' => $otherTenantId,
            'phone' => '0809990001',
            'name' => 'Other Affiliate',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_accounts')->insert([
            'id' => 'aff_referral_other',
            'tenant_id' => $otherTenantId,
            'customer_id' => 'cus_referral_other_affiliate',
            'code' => 'Qq1Ww2',
            'name' => 'Other Tenant Affiliate',
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->withToken($buyerToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/referrals/apply', ['ref' => 'Qq1Ww2'])
            ->assertNotFound();

        $gameId = 'gam_referral_apply';
        $orderId = 'ord_referral_apply';
        $this->insertGame($gameId, 'open');
        $this->insertPaidOrderForCustomer($tenantId, $buyerId, $gameId, 'res_referral_apply', $orderId);
        DB::table('commission_rules')->insert([
            'id' => 'cmr_referral_apply',
            'tenant_id' => $tenantId,
            'affiliate_program_id' => null,
            'affiliate_account_id' => $secondAffiliateId,
            'code' => 'referral_apply_rule',
            'name' => 'Referral Apply Rule',
            'rule_type' => 'fixed_per_order',
            'amount' => 1200,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, app(GrowthService::class)->calculateCommissions($orderId, $tenantId));
        $this->assertDatabaseHas('commission_transactions', [
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'affiliate_account_id' => $secondAffiliateId,
            'affiliate_attribution_id' => $attributionId,
            'amount' => 1200,
        ]);
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $attributionId,
            'status' => 'converted',
            'order_id' => $orderId,
        ]);

        $expiredBuyerId = 'cus_referral_expired_buyer';
        $this->issueCustomerToken($tenantId, $expiredBuyerId);
        $expiredOrderId = 'ord_referral_expired';
        $expiredAttributionId = 'aat_referral_expired';
        DB::table('affiliate_attributions')->insert([
            'id' => $expiredAttributionId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $secondAffiliateId,
            'affiliate_link_id' => null,
            'affiliate_program_id' => null,
            'customer_id' => $expiredBuyerId,
            'order_id' => null,
            'status' => 'pending',
            'attributed_at' => now()->subDays(31),
            'converted_at' => null,
            'metadata_json' => json_encode(['expires_at' => now()->subDay()->toISOString()], JSON_THROW_ON_ERROR),
            'created_at' => now()->subDays(31),
            'updated_at' => now()->subDays(31),
        ]);
        $this->insertPaidOrderForCustomer($tenantId, $expiredBuyerId, $gameId, 'res_referral_expired', $expiredOrderId);

        $this->assertSame(0, app(GrowthService::class)->calculateCommissions($expiredOrderId, $tenantId));
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => $expiredAttributionId,
            'status' => 'expired',
        ]);
        $this->assertDatabaseMissing('commission_transactions', [
            'tenant_id' => $tenantId,
            'order_id' => $expiredOrderId,
        ]);
    }

    private function insertPaidOrderForCustomer(string $tenantId, string $customerId, string $gameId, string $reservationId, string $orderId): void
    {
        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => now()->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => now(),
            'idempotency_key' => 'reserve-'.$reservationId,
            'payload_hash' => hash('sha256', 'reserve-'.$reservationId),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 10000,
            'currency' => 'THB',
            'reference' => 'REF-'.$orderId,
            'admin_note' => null,
            'idempotency_key' => 'order-'.$orderId,
            'payload_hash' => hash('sha256', 'order-'.$orderId),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
