<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$now = now();
$partnerId = 'par_qa_exact6';
$tenantId = 'ten_qa_exact6';
$host = 'localhost';
$gameId = 'gam_qa_exact6';
$numbers = ['654321', '654322', '123421'];
$profileId = 'vsp_'.$gameId;
$distribution = [[
    'set_size' => 3,
    'percent_basis_points' => 10000,
]];
$allocationId = 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20);
$distributionId = 'spd_'.substr(sha1($gameId.':'.$partnerId), 0, 20);
$domainId = 'dom_'.substr(sha1($tenantId.':'.$host), 0, 20);

DB::transaction(function () use (
    $now,
    $partnerId,
    $tenantId,
    $host,
    $gameId,
    $numbers,
    $profileId,
    $distribution,
    $allocationId,
    $distributionId,
    $domainId,
) {
    DB::table('partner_stock_allocations')->where('id', $allocationId)->delete();
    DB::table('stock_partner_distributions')->where('id', $distributionId)->delete();
    DB::table('stock_supply_profiles')->where('id', $profileId)->delete();
    DB::table('games')->where('id', $gameId)->delete();
    DB::table('partner_tenant_domains')->where('id', $domainId)->delete();
    DB::table('partner_tenants')->where('id', $tenantId)->delete();
    DB::table('partners')->where('id', $partnerId)->delete();

    DB::table('partners')->insert([
        'id' => $partnerId,
        'code' => $partnerId,
        'name' => 'QA Exact Six Partner',
        'type' => 'partner_store',
        'status' => 'active',
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('partner_tenants')->insert([
        'id' => $tenantId,
        'partner_id' => $partnerId,
        'code' => $tenantId,
        'name' => 'QA Exact Six Tenant',
        'status' => 'active',
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('partner_tenant_domains')->insert([
        'id' => $domainId,
        'partner_id' => $partnerId,
        'tenant_id' => $tenantId,
        'host' => $host,
        'type' => 'subdomain',
        'status' => 'active',
        'is_primary' => true,
        'verified_at' => $now,
        'ssl_ready_at' => $now,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('games')->insert([
        'id' => $gameId,
        'code' => $gameId,
        'name' => 'QA Exact Six Game',
        'sale_start_at' => $now->copy()->subHour(),
        'draw_at' => $now->copy()->addDay(),
        'close_at' => $now->copy()->addHours(20),
        'closed_at' => null,
        'archived_at' => null,
        'status' => 'open',
        'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    foreach ($numbers as $number) {
        DB::table('base_lottery_numbers')->updateOrInsert(
            ['full_number' => $number],
            [
                'front3' => substr($number, 0, 3),
                'back3' => substr($number, -3),
                'back2' => substr($number, -2),
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );
    }

    DB::table('stock_supply_profiles')->insert([
        'id' => $profileId,
        'game_id' => $gameId,
        'status' => 'active',
        'seed' => 'qa-exact-six-seed',
        'base_count' => count($numbers),
        'total_capacity' => count($numbers) * 3,
        'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
        'created_by_admin_id' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('stock_partner_distributions')->insert([
        'id' => $distributionId,
        'game_id' => $gameId,
        'partner_id' => $partnerId,
        'tenant_id' => $tenantId,
        'percent_basis_points' => 10000,
        'status' => 'active',
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('partner_stock_allocations')->insert([
        'id' => $allocationId,
        'partner_id' => $partnerId,
        'tenant_id' => $tenantId,
        'game_id' => $gameId,
        'quota_id' => null,
        'status' => 'allocated',
        'requested_count' => count($numbers) * 3,
        'allocation_percent_basis_points' => 10000,
        'supply_layer_ids_json' => json_encode([$profileId], JSON_THROW_ON_ERROR),
        'allocated_count' => count($numbers) * 3,
        'recalled_count' => 0,
        'idempotency_key' => 'qa-exact-six-fixture',
        'payload_hash' => hash('sha256', 'qa-exact-six-fixture'),
        'created_by_admin_id' => null,
        'reason' => 'QA exact-six duplicate fixture',
        'cancelled_at' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);
});

$summary = [
    'app_env' => app()->environment(),
    'db_database' => DB::connection()->getDatabaseName(),
    'tenant_domain' => $host,
    'tenant_id' => $tenantId,
    'partner_id' => $partnerId,
    'game_id' => $gameId,
    'exact_full_number' => '654321',
    'expected_duplicate_copies' => 3,
    'base_lottery_numbers' => $numbers,
    'allocation_id' => $allocationId,
    'allocated_count' => count($numbers) * 3,
];

echo json_encode($summary, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
