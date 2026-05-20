<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require 'vendor/autoload.php';

$app = require 'bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$now = now();

$partners = [
    ['id' => 'par_boqa_single', 'code' => 'boqa_single', 'name' => 'BOQA Single Partner'],
    ['id' => 'par_boqa_multi', 'code' => 'boqa_multi', 'name' => 'BOQA Multi Partner'],
    ['id' => 'par_boqa_other', 'code' => 'boqa_other', 'name' => 'BOQA Other Partner'],
    ['id' => 'par_boqa_no_tenant', 'code' => 'boqa_no_tenant', 'name' => 'BOQA No Tenant Partner'],
];

foreach ($partners as $partner) {
    DB::table('partners')->updateOrInsert(
        ['id' => $partner['id']],
        [
            'code' => $partner['code'],
            'name' => $partner['name'],
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );
}

$tenants = [
    ['id' => 'ten_boqa_single', 'partner_id' => 'par_boqa_single', 'code' => 'boqa_single_tenant', 'name' => 'BOQA Single Tenant'],
    ['id' => 'ten_boqa_multi_a', 'partner_id' => 'par_boqa_multi', 'code' => 'boqa_multi_a', 'name' => 'BOQA Multi Tenant A'],
    ['id' => 'ten_boqa_multi_b', 'partner_id' => 'par_boqa_multi', 'code' => 'boqa_multi_b', 'name' => 'BOQA Multi Tenant B'],
    ['id' => 'ten_boqa_other', 'partner_id' => 'par_boqa_other', 'code' => 'boqa_other_tenant', 'name' => 'BOQA Other Tenant'],
];

foreach ($tenants as $tenant) {
    DB::table('partner_tenants')->updateOrInsert(
        ['id' => $tenant['id']],
        [
            'partner_id' => $tenant['partner_id'],
            'code' => $tenant['code'],
            'name' => $tenant['name'],
            'status' => 'active',
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );
}

DB::table('games')->updateOrInsert(
    ['id' => 'gam_boqa_alloc'],
    [
        'code' => 'boqa_alloc',
        'name' => 'BOQA Allocation Draw',
        'sale_start_at' => now()->subHour(),
        'draw_at' => now()->addDay(),
        'close_at' => now()->addHours(20),
        'closed_at' => null,
        'archived_at' => null,
        'status' => 'open',
        'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
        'created_at' => $now,
        'updated_at' => $now,
    ],
);

DB::table('stock_supply_profiles')->updateOrInsert(
    ['id' => 'vsp_boqa_alloc'],
    [
        'game_id' => 'gam_boqa_alloc',
        'status' => 'active',
        'seed' => 'boqa-allocation-seed',
        'base_count' => 10,
        'total_capacity' => 10,
        'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
        'created_by_admin_id' => 'adm_platform_owner',
        'created_at' => $now,
        'updated_at' => $now,
    ],
);

DB::table('stock_partner_distributions')
    ->where('game_id', 'gam_boqa_alloc')
    ->whereIn('partner_id', ['par_boqa_single', 'par_boqa_multi', 'par_boqa_other'])
    ->delete();

DB::table('partner_stock_allocations')
    ->where('game_id', 'gam_boqa_alloc')
    ->delete();

echo json_encode([
    'fixture_ready' => true,
    'game_id' => 'gam_boqa_alloc',
    'partners' => array_column($partners, 'id'),
    'tenants' => array_column($tenants, 'id'),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
