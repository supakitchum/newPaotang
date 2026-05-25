<?php

namespace Tests\Support;

use Illuminate\Support\Facades\DB;

trait M8GrowthFixtures
{
    use PartnerStoreFixtures;

    /**
     * @return array<string, mixed>
     */
    protected function prepareM8World(string $suffix = 'main'): array
    {
        $this->seedDefaultRbac();

        $key = substr(sha1($suffix), 0, 10);
        $partnerId = 'par_m8_'.$key;
        $tenantId = 'ten_m8_'.$key;
        $gameId = 'gam_m8_'.$key;
        $customerId = 'cus_m8_'.$key;
        $reservationId = 'res_m8_'.$key;
        $orderId = 'ord_m8_'.$key;
        $stockId = 'stk_m8_'.$key;
        $localStockId = 'lsi_m8_'.$key;
        $ticketId = 'tic_m8_'.$key;
        $customerNo = strtoupper((string) preg_replace('/[^A-Za-z0-9]+/', '', $tenantId)).'ABCDEF23';

        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $this->insertGame($gameId, 'open');

        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'customer_no' => $customerNo,
            'phone' => '080'.substr($key, 0, 7),
            'name' => 'M8 Customer '.$suffix,
            'email' => $suffix.'@m8.example.test',
            'password_hash' => null,
            'avatar_url' => null,
            'last_login_at' => null,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => '88'.substr('0000'.$key, 0, 4),
            'front3' => '880',
            'back3' => '001',
            'back2' => '01',
            'status' => 'sold',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('local_stock_items')->insert([
            'id' => $localStockId,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'store_id' => 'store-'.$suffix,
            'game_id' => $gameId,
            'stock_item_id' => $stockId,
            'allocation_id' => null,
            'full_number' => '88'.substr('0000'.$key, 0, 4),
            'front3' => '880',
            'back3' => '001',
            'back2' => '01',
            'image_url' => null,
            'image_thumb_url' => null,
            'status' => 'sold',
            'synced_at' => now(),
            'reserved_at' => now(),
            'sold_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => now()->addHour(),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => now(),
            'idempotency_key' => 'm8-reserve-'.$suffix,
            'payload_hash' => hash('sha256', 'm8-reserve-'.$suffix),
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
            'reference' => 'M8-'.$suffix,
            'admin_note' => null,
            'idempotency_key' => 'm8-order-'.$suffix,
            'payload_hash' => hash('sha256', 'm8-order-'.$suffix),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('tickets')->insert([
            'id' => $ticketId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'order_id' => $orderId,
            'local_stock_item_id' => $localStockId,
            'game_id' => $gameId,
            'full_number' => '88'.substr('0000'.$key, 0, 4),
            'status' => 'active',
            'image_url' => null,
            'image_thumb_url' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'customer_id' => $customerId,
            'customer_no' => $customerNo,
            'order_id' => $orderId,
            'ticket_id' => $ticketId,
            'suffix' => $suffix,
        ];
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function m8TenantAdmin(array $world, array $permissions, string $suffix): array
    {
        return $this->createTenantSession(
            $world['tenant_id'],
            $world['partner_id'],
            $permissions,
            'adm_m8_'.substr(sha1($suffix.$world['tenant_id']), 0, 18),
            'm8-'.$suffix.'@example.test',
        );
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function m8CentralAdmin(array $permissions, string $suffix): array
    {
        return $this->createCentralSession(
            $permissions,
            'adm_m8c_'.substr(sha1($suffix), 0, 17),
            'm8-central-'.$suffix.'@example.test',
        );
    }

    /**
     * @return array<string, string>
     */
    protected function insertM8AffiliateGraph(array $world, string $suffix = 'main', int $amount = 1500): array
    {
        $key = substr(sha1($suffix.$world['tenant_id']), 0, 10);
        $affiliateId = 'aff_m8_'.$key;
        $programId = 'afp_m8_'.$key;
        $linkId = 'afl_m8_'.$key;
        $attributionId = 'aat_m8_'.$key;
        $ruleId = 'cmr_m8_'.$key;
        $affiliateCode = 'A'.substr($key, 0, 5);
        $linkCode = 'L'.substr($key, 0, 5);

        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'code' => $affiliateCode,
            'name' => 'Affiliate '.$suffix,
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

        DB::table('affiliate_programs')->insert([
            'id' => $programId,
            'tenant_id' => $world['tenant_id'],
            'code' => 'program_'.$key,
            'name' => 'Program '.$suffix,
            'status' => 'active',
            'starts_at' => null,
            'ends_at' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('affiliate_links')->insert([
            'id' => $linkId,
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_program_id' => $programId,
            'code' => $linkCode,
            'url' => 'https://newpaotang.local/?ref='.$linkCode,
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('affiliate_attributions')->insert([
            'id' => $attributionId,
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_link_id' => $linkId,
            'affiliate_program_id' => $programId,
            'customer_id' => $world['customer_id'],
            'order_id' => null,
            'status' => 'pending',
            'attributed_at' => now()->subHour(),
            'converted_at' => null,
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('commission_rules')->insert([
            'id' => $ruleId,
            'tenant_id' => $world['tenant_id'],
            'affiliate_program_id' => $programId,
            'affiliate_account_id' => null,
            'code' => 'rule_'.$key,
            'name' => 'Rule '.$suffix,
            'rule_type' => 'fixed_per_order',
            'amount' => $amount,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'affiliate_id' => $affiliateId,
            'program_id' => $programId,
            'link_id' => $linkId,
            'attribution_id' => $attributionId,
            'rule_id' => $ruleId,
        ];
    }
}
