<?php

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$baseUrl = rtrim(getenv('QA_API_BASE') ?: 'http://platform-api:8000/api/v1', '/');
$tenantId = 'ten_demo_alpha';
$run = strtolower(bin2hex(random_bytes(4)));
$events = [];

$centralToken = null;
$tenantToken = null;

$record = function (string $label, string $method, string $path, int $status, array $headers, array $payload = [], array $query = [], mixed $json = null) use (&$events): void {
    $events[] = [
        'label' => $label,
        'method' => strtoupper($method),
        'path' => $path,
        'status' => $status,
        'query_keys' => array_keys($query),
        'payload_keys' => payloadKeys($payload),
        'headers' => [
            'x_admin_scope' => $headers['X-Admin-Scope'] ?? null,
            'x_tenant_id' => $headers['X-Tenant-Id'] ?? null,
            'x_request_id_present' => isset($headers['X-Request-Id']),
            'idempotency_key_present' => isset($headers['Idempotency-Key']),
            'authorization_present' => isset($headers['Authorization']),
        ],
        'resource' => summarizeResource($json),
        'error_code' => is_array($json) ? ($json['error']['code'] ?? $json['error'] ?? null) : null,
    ];
};

$login = function (string $scope) use ($baseUrl, $tenantId, $record): string {
    $payload = $scope === 'central'
        ? [
            'email' => 'admin@newpaotang.test',
            'password' => (string) config('platform.seed.central_admin_password'),
            'scope' => 'central',
        ]
        : [
            'email' => 'owner@alpha.newpaotang.test',
            'password' => (string) config('platform.seed.tenant_owner_password'),
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ];

    $response = Http::acceptJson()->timeout(20)->post($baseUrl.'/auth/admin/login', $payload);
    $json = $response->json();

    $record($scope.'-login', 'POST', '/auth/admin/login', $response->status(), [], [
        'email' => $payload['email'],
        'scope' => $payload['scope'],
        'tenant_id' => $payload['tenant_id'] ?? null,
    ], [], [
        'active_scope' => $json['active_scope'] ?? null,
        'access_token_present' => isset($json['access_token']),
        'refresh_token_present' => isset($json['refresh_token']),
    ]);

    if ($response->failed() || ! is_array($json) || ! isset($json['access_token'])) {
        throw new RuntimeException($scope.' login failed with HTTP '.$response->status());
    }

    return (string) $json['access_token'];
};

$request = function (string $scope, string $label, string $method, string $path, array $payload = [], array $query = [], bool $write = false) use ($baseUrl, $tenantId, &$centralToken, &$tenantToken, $record): array {
    $headers = [
        'Accept' => 'application/json',
        'X-Admin-Scope' => $scope,
        'X-Request-Id' => 'qa-msct-'.$label,
        'Authorization' => 'Bearer '.($scope === 'central' ? $centralToken : $tenantToken),
    ];

    if ($scope === 'tenant') {
        $headers['X-Tenant-Id'] = $tenantId;
    }

    if ($write) {
        $headers['Idempotency-Key'] = 'qa-msct-'.$label.'-'.bin2hex(random_bytes(4));
    }

    $pending = Http::withHeaders($headers)->timeout(20);
    $url = $baseUrl.$path;
    $response = match (strtoupper($method)) {
        'GET' => $pending->get($url, $query),
        'POST' => $pending->post($url, $payload),
        default => throw new InvalidArgumentException('Unsupported method '.$method),
    };

    $json = $response->body() === '' ? null : $response->json();
    $record($label, $method, $path, $response->status(), $headers, $payload, $query, $json);

    if ($response->failed()) {
        throw new RuntimeException($label.' failed with HTTP '.$response->status().': '.substr($response->body(), 0, 500));
    }

    return is_array($json) ? $json : [];
};

$createCommissionFixture = function () use ($tenantId, $run): array {
    $now = now();
    $tenant = DB::table('partner_tenants')->where('id', $tenantId)->first();

    if ($tenant === null) {
        throw new RuntimeException('Tenant fixture not found: '.$tenantId);
    }

    $gameId = 'gam_msct_'.$run;
    $customerId = 'cus_msct_'.$run;
    $stockId = 'stk_msct_'.$run;
    $localStockId = 'lsi_msct_'.$run;
    $reservationId = 'res_msct_'.$run;
    $orderId = 'ord_msct_'.$run;
    $affiliateId = 'aff_msct_'.$run;
    $programId = 'afp_msct_'.$run;
    $linkId = 'afl_msct_'.$run;
    $attributionId = 'aat_msct_'.$run;
    $ruleId = 'cmr_msct_'.$run;
    $commissionId = 'com_msct_'.$run;

    DB::transaction(function () use ($tenant, $tenantId, $run, $now, $gameId, $customerId, $stockId, $localStockId, $reservationId, $orderId, $affiliateId, $programId, $linkId, $attributionId, $ruleId, $commissionId): void {
        DB::table('games')->insert([
            'id' => $gameId,
            'code' => 'qa-msct-'.$run,
            'name' => 'QA MSCT '.$run,
            'draw_at' => $now->copy()->addDays(7),
            'close_at' => $now->copy()->addDays(6),
            'closed_at' => null,
            'archived_at' => null,
            'status' => 'open',
            'metadata_json' => json_encode(['source' => 'qa-msct', 'run' => $run], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'phone' => '089'.substr($run, 0, 7),
            'name' => 'QA Commission Customer '.$run,
            'email' => 'qa-msct-'.$run.'@example.test',
            'password_hash' => null,
            'avatar_url' => null,
            'last_login_at' => null,
            'status' => 'active',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('stock_items')->insert([
            'id' => $stockId,
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => '77'.substr($run.'0000', 0, 4),
            'front3' => '770',
            'back3' => '001',
            'back2' => '01',
            'status' => 'sold',
            'partner_id' => (string) $tenant->partner_id,
            'tenant_id' => $tenantId,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('local_stock_items')->insert([
            'id' => $localStockId,
            'tenant_id' => $tenantId,
            'partner_id' => (string) $tenant->partner_id,
            'store_id' => 'qa-msct',
            'game_id' => $gameId,
            'stock_item_id' => $stockId,
            'allocation_id' => null,
            'full_number' => '77'.substr($run.'0000', 0, 4),
            'front3' => '770',
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
            'idempotency_key' => 'qa-msct-res-'.$run,
            'payload_hash' => hash('sha256', 'qa-msct-res-'.$run),
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
            'reference' => 'QA-MSCT-'.$run,
            'admin_note' => null,
            'idempotency_key' => 'qa-msct-order-'.$run,
            'payload_hash' => hash('sha256', 'qa-msct-order-'.$run),
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
            'code' => 'qa_aff_'.$run,
            'name' => 'QA Affiliate '.$run,
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => json_encode(['source' => 'qa-msct', 'run' => $run], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('affiliate_programs')->insert([
            'id' => $programId,
            'tenant_id' => $tenantId,
            'code' => 'qa_prog_'.$run,
            'name' => 'QA Program '.$run,
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
            'code' => 'qa_link_'.$run,
            'url' => 'https://newpaotang.local/a/qa_link_'.$run,
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
            'code' => 'qa_rule_'.$run,
            'name' => 'QA Rule '.$run,
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
            'idempotency_key' => 'qa-msct-calc-'.$run,
            'payload_hash' => hash('sha256', 'qa-msct-calc-'.$run),
            'calculated_at' => $now,
            'approved_by_admin_id' => null,
            'approved_at' => null,
            'metadata_json' => json_encode(['source' => 'qa-msct', 'run' => $run], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    });

    return [
        'game_id' => $gameId,
        'commission_id' => $commissionId,
        'affiliate_account_id' => $affiliateId,
        'order_id' => $orderId,
        'commission_rule_id' => $ruleId,
    ];
};

$centralToken = $login('central');
$tenantToken = $login('tenant');

$fixture = $createCommissionFixture();
$stockGameId = $fixture['game_id'];

$stockGenerate = $request('central', 'stock-generate-fixture', 'POST', '/admin/central/stock/generate', [
    'game_id' => $stockGameId,
    'start_number' => 900001,
    'count' => 3,
    'reason' => 'qa fixture stock for master stock list/export',
], [], true);

$stockList = $request('central', 'stock-list-filtered', 'GET', '/admin/central/stock', [], [
    'game_id' => $stockGameId,
    'status' => 'available',
    'limit' => 2,
]);

$stockCursor = null;
if (($stockList['meta']['has_more'] ?? false) === true && isset($stockList['meta']['next_cursor'])) {
    $stockCursor = (string) $stockList['meta']['next_cursor'];
    $request('central', 'stock-list-cursor', 'GET', '/admin/central/stock', [], [
        'game_id' => $stockGameId,
        'status' => 'available',
        'cursor' => $stockCursor,
        'limit' => 2,
    ]);
}

$stockExport = $request('central', 'stock-export', 'POST', '/admin/central/stock/exports', [
    'game_id' => $stockGameId,
    'filters' => ['status' => 'available'],
    'reason' => 'qa focused export check',
], [], true);

$commissionList = $request('tenant', 'commission-list-calculated', 'GET', '/admin/tenant/commission-transactions', [], [
    'status' => 'calculated',
    'limit' => 20,
]);

$commissionApprove = $request('tenant', 'commission-approve', 'POST', '/admin/tenant/commission-transactions/'.$fixture['commission_id'].'/approve', [
    'reason' => 'qa approve safe fixture commission',
], [], true);

$commissionApprovedList = $request('tenant', 'commission-list-approved', 'GET', '/admin/tenant/commission-transactions', [], [
    'status' => 'approved',
    'limit' => 20,
]);

$result = [
    'result' => 'PASS',
    'run' => $run,
    'base_url' => $baseUrl,
    'tenant_id' => $tenantId,
    'fixtures' => [
        'game_id' => $stockGameId,
        'stock_batch_id' => $stockGenerate['id'] ?? null,
        'commission_id' => $fixture['commission_id'],
        'affiliate_account_id' => $fixture['affiliate_account_id'],
        'order_id' => $fixture['order_id'],
        'commission_rule_id' => $fixture['commission_rule_id'],
    ],
    'checks' => [
        'stock_list_loaded_with_rows' => count($stockList['data'] ?? []) > 0,
        'stock_list_has_cursor_meta' => array_key_exists('meta', $stockList) && array_key_exists('next_cursor', $stockList['meta'] ?? []),
        'stock_export_accepted' => ($stockExport['type'] ?? null) === 'export' && ($stockExport['status'] ?? null) === 'pending',
        'commission_list_loaded_with_fixture' => in_array($fixture['commission_id'], array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $commissionList['data'] ?? []), true),
        'commission_approve_status_round_trip' => ($commissionApprove['id'] ?? null) === $fixture['commission_id'] && ($commissionApprove['status'] ?? null) === 'approved',
        'commission_approved_list_contains_fixture' => in_array($fixture['commission_id'], array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $commissionApprovedList['data'] ?? []), true),
        'all_writes_had_idempotency_key' => collect($events)
            ->filter(fn (array $event): bool => in_array($event['method'], ['POST', 'PATCH', 'DELETE'], true) && ! str_contains((string) $event['path'], '/auth/admin/login'))
            ->every(fn (array $event): bool => $event['headers']['idempotency_key_present'] === true),
        'central_scope_headers_present' => collect($events)
            ->filter(fn (array $event): bool => str_starts_with((string) $event['label'], 'stock-'))
            ->every(fn (array $event): bool => $event['headers']['x_admin_scope'] === 'central'),
        'tenant_scope_headers_present' => collect($events)
            ->filter(fn (array $event): bool => str_starts_with((string) $event['label'], 'commission-'))
            ->every(fn (array $event): bool => $event['headers']['x_admin_scope'] === 'tenant' && $event['headers']['x_tenant_id'] === $tenantId),
        'no_stock_or_commission_detail_get_called' => collect($events)
            ->filter(fn (array $event): bool => $event['method'] === 'GET')
            ->every(fn (array $event): bool => ! preg_match('#^/admin/central/stock/[^/?]+$#', (string) $event['path'])
                && ! preg_match('#^/admin/tenant/commission-transactions/[^/?]+$#', (string) $event['path'])),
    ],
    'events' => $events,
];

foreach ($result['checks'] as $check => $passed) {
    if ($passed !== true) {
        $result['result'] = 'FAIL';
        $result['failed_check'] = $check;
        break;
    }
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL;

function payloadKeys(mixed $value, string $prefix = ''): array
{
    if (! is_array($value)) {
        return [];
    }

    $keys = [];
    foreach ($value as $key => $entry) {
        $path = $prefix === '' ? (string) $key : $prefix.'.'.$key;
        $keys[] = $path;
        if (is_array($entry) && array_is_list($entry) === false) {
            array_push($keys, ...payloadKeys($entry, $path));
        }
    }

    return $keys;
}

function summarizeResource(mixed $json): array
{
    if (! is_array($json)) {
        return [];
    }

    if (array_key_exists('data', $json) && is_array($json['data'])) {
        return [
            'list_count' => count($json['data']),
            'ids' => array_values(array_filter(array_map(fn (mixed $row): ?string => is_array($row) ? (string) ($row['id'] ?? '') : null, $json['data']))),
            'meta' => [
                'next_cursor_present' => isset($json['meta']['next_cursor']),
                'has_more' => $json['meta']['has_more'] ?? null,
            ],
        ];
    }

    return [
        'id' => $json['id'] ?? null,
        'tenant_id' => $json['tenant_id'] ?? null,
        'game_id' => $json['game_id'] ?? null,
        'status' => $json['status'] ?? null,
        'type' => $json['type'] ?? null,
        'transaction_type' => $json['transaction_type'] ?? null,
        'amount' => is_array($json['amount'] ?? null) ? ($json['amount']['amount'] ?? null) : null,
    ];
}
