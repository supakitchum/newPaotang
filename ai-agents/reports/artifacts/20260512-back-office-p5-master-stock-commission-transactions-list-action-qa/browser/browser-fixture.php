<?php

use Illuminate\Support\Facades\DB;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$tenantId = 'ten_demo_alpha';
$run = strtolower(bin2hex(random_bytes(4)));
$now = now();

$tenant = DB::table('partner_tenants')->where('id', $tenantId)->first();
if ($tenant === null) {
    throw new RuntimeException('Tenant fixture not found: '.$tenantId);
}

$gameId = 'gam_bmsct_'.$run;
$customerId = 'cus_bmsct_'.$run;
$stockIds = [
    'stk_bmscta_'.$run,
    'stk_bmsctb_'.$run,
    'stk_bmsctc_'.$run,
];
$localStockId = 'lsi_bmsct_'.$run;
$reservationId = 'res_bmsct_'.$run;
$orderId = 'ord_bmsct_'.$run;
$affiliateId = 'aff_bmsct_'.$run;
$programId = 'afp_bmsct_'.$run;
$linkId = 'afl_bmsct_'.$run;
$attributionId = 'aat_bmsct_'.$run;
$ruleId = 'cmr_bmsct_'.$run;
$commissionId = 'com_bmsct_'.$run;

DB::transaction(function () use ($tenant, $tenantId, $run, $now, $gameId, $customerId, $stockIds, $localStockId, $reservationId, $orderId, $affiliateId, $programId, $linkId, $attributionId, $ruleId, $commissionId): void {
    DB::table('games')->insert([
        'id' => $gameId,
        'code' => 'qa-bmsct-'.$run,
        'name' => 'QA Browser MSCT '.$run,
        'draw_at' => $now->copy()->addDays(7),
        'close_at' => $now->copy()->addDays(6),
        'closed_at' => null,
        'archived_at' => null,
        'status' => 'open',
        'metadata_json' => json_encode(['source' => 'qa-browser-msct', 'run' => $run], JSON_THROW_ON_ERROR),
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    $numbers = ['910001', '910002', '910003'];
    foreach ($stockIds as $index => $stockId) {
        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => $numbers[$index],
            'front3' => substr($numbers[$index], 0, 3),
            'back3' => substr($numbers[$index], -3),
            'back2' => substr($numbers[$index], -2),
            'status' => 'available',
            'partner_id' => null,
            'tenant_id' => null,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    DB::table('customers')->insert([
        'id' => $customerId,
        'tenant_id' => $tenantId,
        'phone' => '088'.substr($run, 0, 7),
        'name' => 'QA Browser Commission Customer '.$run,
        'email' => 'qa-browser-msct-'.$run.'@example.test',
        'password_hash' => null,
        'avatar_url' => null,
        'last_login_at' => null,
        'status' => 'active',
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('local_stock_items')->insert([
        'id' => $localStockId,
        'tenant_id' => $tenantId,
        'partner_id' => (string) $tenant->partner_id,
        'store_id' => 'qa-browser-msct',
        'game_id' => $gameId,
        'stock_item_id' => $stockIds[0],
        'allocation_id' => null,
        'full_number' => '910001',
        'front3' => '910',
        'back3' => '001',
        'back2' => '01',
        'image_url' => null,
        'image_thumb_url' => null,
        'status' => 'sold',
        'synced_at' => $now,
        'reserved_at' => $now,
        'sold_at' => $now,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('stock_reservations')->insert([
        'id' => $reservationId,
        'tenant_id' => $tenantId,
        'customer_id' => $customerId,
        'game_id' => $gameId,
        'status' => 'converted',
        'expires_at' => $now->copy()->addHour(),
        'released_at' => null,
        'cancelled_at' => null,
        'converted_at' => $now,
        'idempotency_key' => 'qa-bmsct-res-'.$run,
        'payload_hash' => hash('sha256', 'qa-bmsct-res-'.$run),
        'released_idempotency_key' => null,
        'released_payload_hash' => null,
        'cancelled_idempotency_key' => null,
        'cancelled_payload_hash' => null,
        'cancelled_by_admin_id' => null,
        'cancel_reason' => null,
        'created_at' => $now,
        'updated_at' => $now,
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
        'reference' => 'QA-BMSCT-'.$run,
        'admin_note' => null,
        'idempotency_key' => 'qa-bmsct-order-'.$run,
        'payload_hash' => hash('sha256', 'qa-bmsct-order-'.$run),
        'paid_at' => $now,
        'cancelled_at' => null,
        'refunded_at' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('affiliate_accounts')->insert([
        'id' => $affiliateId,
        'tenant_id' => $tenantId,
        'customer_id' => null,
        'code' => 'qa_baff_'.$run,
        'name' => 'QA Browser Affiliate '.$run,
        'phone' => null,
        'email' => null,
        'status' => 'active',
        'wallet_balance_amount' => 0,
        'currency' => 'THB',
        'payout_profile_json' => null,
        'metadata_json' => json_encode(['source' => 'qa-browser-msct', 'run' => $run], JSON_THROW_ON_ERROR),
        'created_by_admin_id' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('affiliate_programs')->insert([
        'id' => $programId,
        'tenant_id' => $tenantId,
        'code' => 'qa_bprog_'.$run,
        'name' => 'QA Browser Program '.$run,
        'status' => 'active',
        'starts_at' => null,
        'ends_at' => null,
        'metadata_json' => null,
        'created_by_admin_id' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('affiliate_links')->insert([
        'id' => $linkId,
        'tenant_id' => $tenantId,
        'affiliate_account_id' => $affiliateId,
        'affiliate_program_id' => $programId,
        'code' => 'qa_blink_'.$run,
        'url' => 'https://newpaotang.local/a/qa_blink_'.$run,
        'status' => 'active',
        'metadata_json' => null,
        'created_by_admin_id' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('affiliate_attributions')->insert([
        'id' => $attributionId,
        'tenant_id' => $tenantId,
        'affiliate_account_id' => $affiliateId,
        'affiliate_link_id' => $linkId,
        'affiliate_program_id' => $programId,
        'customer_id' => $customerId,
        'order_id' => $orderId,
        'status' => 'converted',
        'attributed_at' => $now->copy()->subHour(),
        'converted_at' => $now,
        'metadata_json' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('commission_rules')->insert([
        'id' => $ruleId,
        'tenant_id' => $tenantId,
        'affiliate_program_id' => $programId,
        'affiliate_account_id' => null,
        'code' => 'qa_brule_'.$run,
        'name' => 'QA Browser Rule '.$run,
        'rule_type' => 'fixed_per_order',
        'amount' => 1500,
        'rate_bps' => 0,
        'currency' => 'THB',
        'status' => 'active',
        'metadata_json' => null,
        'created_by_admin_id' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('commission_transactions')->insert([
        'id' => $commissionId,
        'tenant_id' => $tenantId,
        'affiliate_account_id' => $affiliateId,
        'affiliate_attribution_id' => $attributionId,
        'order_id' => $orderId,
        'commission_rule_id' => $ruleId,
        'original_commission_id' => null,
        'transaction_type' => 'commission',
        'status' => 'calculated',
        'amount' => 1500,
        'currency' => 'THB',
        'idempotency_key' => 'qa-bmsct-calc-'.$run,
        'payload_hash' => hash('sha256', 'qa-bmsct-calc-'.$run),
        'calculated_at' => $now,
        'approved_by_admin_id' => null,
        'approved_at' => null,
        'metadata_json' => json_encode(['source' => 'qa-browser-msct', 'run' => $run], JSON_THROW_ON_ERROR),
        'created_at' => $now,
        'updated_at' => $now,
    ]);
});

echo json_encode([
    'run' => $run,
    'tenant_id' => $tenantId,
    'game_id' => $gameId,
    'stock_ids' => $stockIds,
    'commission_id' => $commissionId,
    'affiliate_account_id' => $affiliateId,
    'order_id' => $orderId,
    'commission_rule_id' => $ruleId,
], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL;
