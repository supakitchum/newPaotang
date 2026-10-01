<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$baseUrl = rtrim((string) getenv('QA_API_BASE'), '/') ?: 'http://127.0.0.1:8000/api/v1';
$tenantId = 'ten_demo_alpha';
$now = now();

$tenant = DB::table('partner_tenants')->where('id', $tenantId)->first();
if ($tenant === null) {
    throw new RuntimeException('Seed tenant not found.');
}
$partnerId = (string) $tenant->partner_id;

$gameId = DB::table('games')->orderBy('id')->value('id');
if ($gameId === null) {
    $gameId = 'gam_p5_read';
    DB::table('games')->insert([
        'id' => $gameId,
        'code' => 'p5-read',
        'name' => 'P5 Read Game',
        'draw_at' => $now->copy()->addDays(7),
        'close_at' => $now->copy()->addDays(6),
        'status' => 'open',
        'metadata_json' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);
}

$fixtures = [
    'customer_id' => 'cus_p5_read',
    'stock_item_id' => 'stk_p5_read',
    'local_stock_item_id' => 'lsi_p5_read',
    'reservation_id' => 'res_p5_read',
    'order_id' => 'ord_p5_read',
    'ticket_id' => 'tic_p5_read',
    'affiliate_id' => 'aff_p5_read',
    'program_id' => 'afp_p5_read',
    'link_id' => 'afl_p5_read',
    'attribution_id' => 'aat_p5_read',
];

DB::transaction(function () use ($fixtures, $tenantId, $partnerId, $gameId, $now): void {
    DB::table('customers')->updateOrInsert(
        ['id' => $fixtures['customer_id']],
        [
            'tenant_id' => $tenantId,
            'phone' => '0800000505',
            'email' => 'p5-read@example.test',
            'password_hash' => null,
            'avatar_url' => null,
            'name' => 'P5 Read Customer',
            'status' => 'active',
            'last_login_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('stock_items')->updateOrInsert(
        ['id' => $fixtures['stock_item_id']],
        [
            'game_id' => $gameId,
            'batch_id' => null,
            'full_number' => '950505',
            'front3' => '950',
            'back3' => '505',
            'back2' => '05',
            'status' => 'allocated',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('local_stock_items')->updateOrInsert(
        ['id' => $fixtures['local_stock_item_id']],
        [
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'store_id' => 'p5-read-store',
            'game_id' => $gameId,
            'stock_item_id' => $fixtures['stock_item_id'],
            'allocation_id' => null,
            'full_number' => '950505',
            'front3' => '950',
            'back3' => '505',
            'back2' => '05',
            'image_url' => null,
            'image_thumb_url' => null,
            'status' => 'sold',
            'synced_at' => $now,
            'reserved_at' => $now,
            'sold_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('stock_reservations')->updateOrInsert(
        ['id' => $fixtures['reservation_id']],
        [
            'tenant_id' => $tenantId,
            'customer_id' => $fixtures['customer_id'],
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => $now->copy()->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => $now,
            'idempotency_key' => 'p5-read-reservation',
            'payload_hash' => hash('sha256', 'p5-read-reservation'),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('stock_reservation_items')->updateOrInsert(
        ['reservation_id' => $fixtures['reservation_id'], 'local_stock_item_id' => $fixtures['local_stock_item_id']],
        [
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'status' => 'converted',
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('orders')->updateOrInsert(
        ['id' => $fixtures['order_id']],
        [
            'tenant_id' => $tenantId,
            'customer_id' => $fixtures['customer_id'],
            'reservation_id' => $fixtures['reservation_id'],
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 8000,
            'currency' => 'THB',
            'reference' => 'P5-READ-ORDER',
            'admin_note' => null,
            'idempotency_key' => 'p5-read-order',
            'payload_hash' => hash('sha256', 'p5-read-order'),
            'paid_at' => $now,
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('tickets')->updateOrInsert(
        ['id' => $fixtures['ticket_id']],
        [
            'tenant_id' => $tenantId,
            'customer_id' => $fixtures['customer_id'],
            'order_id' => $fixtures['order_id'],
            'local_stock_item_id' => $fixtures['local_stock_item_id'],
            'game_id' => $gameId,
            'full_number' => '950505',
            'status' => 'active',
            'image_url' => null,
            'image_thumb_url' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('affiliate_accounts')->updateOrInsert(
        ['id' => $fixtures['affiliate_id']],
        [
            'tenant_id' => $tenantId,
            'customer_id' => null,
            'code' => 'p5_read_affiliate',
            'name' => 'P5 Read Affiliate',
            'phone' => null,
            'email' => 'p5-affiliate@example.test',
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('affiliate_programs')->updateOrInsert(
        ['id' => $fixtures['program_id']],
        [
            'tenant_id' => $tenantId,
            'code' => 'p5_read_program',
            'name' => 'P5 Read Program',
            'status' => 'active',
            'starts_at' => null,
            'ends_at' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('affiliate_links')->updateOrInsert(
        ['id' => $fixtures['link_id']],
        [
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $fixtures['affiliate_id'],
            'affiliate_program_id' => $fixtures['program_id'],
            'code' => 'p5_read_link',
            'url' => 'https://qa.example.test/p5-read-link',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('affiliate_attributions')->updateOrInsert(
        ['id' => $fixtures['attribution_id']],
        [
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $fixtures['affiliate_id'],
            'affiliate_link_id' => $fixtures['link_id'],
            'affiliate_program_id' => $fixtures['program_id'],
            'customer_id' => $fixtures['customer_id'],
            'order_id' => $fixtures['order_id'],
            'status' => 'pending',
            'attributed_at' => $now->copy()->subHour(),
            'converted_at' => null,
            'metadata_json' => json_encode(['source' => 'p5-read-qa'], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('partner_health_checks')->updateOrInsert(
        ['partner_id' => $partnerId, 'check_key' => 'p5_read_runtime'],
        [
            'id' => 'phc_p5_read',
            'tenant_id' => $tenantId,
            'health_status' => 'healthy',
            'checked_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('partner_daily_usage_summaries')->updateOrInsert(
        ['partner_id' => $partnerId, 'tenant_id' => $tenantId, 'usage_date' => '2026-05-11'],
        [
            'id' => 'pdu_p5_read',
            'api_request_count' => 55,
            'booking_request_count' => 3,
            'checkout_request_count' => 2,
            'order_count' => 1,
            'sold_ticket_count' => 1,
            'image_bandwidth_gb' => 0.125,
            'storage_gb' => 0.250,
            'queue_job_count' => 7,
            'rate_limited_count' => 0,
            'error_count' => 0,
            'sync_event_count' => 2,
            'labels_json' => json_encode(['source' => 'p5-read-qa'], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );
});

$centralToken = login($baseUrl, [
    'email' => (string) config('platform.seed.central_admin_email'),
    'password' => (string) config('platform.seed.central_admin_password'),
    'scope' => 'central',
], ['X-Admin-Scope: central']);

$tenantToken = login($baseUrl, [
    'email' => 'owner@alpha.newpaotang.test',
    'password' => (string) config('platform.seed.tenant_owner_password'),
    'scope' => 'tenant',
    'tenant_id' => $tenantId,
], ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);

$steps = [];
$steps[] = capture('central dashboard summary', $baseUrl, 'GET', '/admin/central/dashboard/summary', $centralToken, ['X-Admin-Scope: central']);
$steps[] = capture('tenant dashboard summary', $baseUrl, 'GET', '/admin/tenant/dashboard/summary', $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant tickets list', $baseUrl, 'GET', '/admin/tenant/tickets?limit=20', $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant ticket detail', $baseUrl, 'GET', '/admin/tenant/tickets/'.$fixtures['ticket_id'], $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant affiliate attributions list', $baseUrl, 'GET', '/admin/tenant/affiliate-attributions?limit=20', $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant affiliate attribution detail', $baseUrl, 'GET', '/admin/tenant/affiliate-attributions/'.$fixtures['attribution_id'], $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant monitoring summary', $baseUrl, 'GET', '/admin/tenant/monitoring', $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);
$steps[] = capture('tenant usage summary filtered', $baseUrl, 'GET', '/admin/tenant/usage?date_from=2026-05-01&date_to=2026-05-31', $tenantToken, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);

echo json_encode([
    'generated_at' => now()->toIso8601String(),
    'base_url' => $baseUrl,
    'fixtures' => $fixtures + ['tenant_id' => $tenantId, 'partner_id' => $partnerId, 'game_id' => $gameId],
    'steps' => $steps,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;

function login(string $baseUrl, array $payload, array $headers): string
{
    $response = httpJson($baseUrl.'/auth/admin/login', 'POST', $headers, $payload);

    if (($response['status'] ?? 0) !== 200 || ! isset($response['json']['access_token'])) {
        throw new RuntimeException('Admin login failed with HTTP '.$response['status']);
    }

    return (string) $response['json']['access_token'];
}

function capture(string $name, string $baseUrl, string $method, string $path, string $token, array $scopeHeaders): array
{
    $response = httpJson($baseUrl.$path, $method, array_merge($scopeHeaders, ['Authorization: Bearer '.$token]), null);
    $json = $response['json'];

    return [
        'name' => $name,
        'method' => $method,
        'path' => $path,
        'status' => $response['status'],
        'request_headers' => safeHeaderSummary($scopeHeaders),
        'summary' => summarize($json),
    ];
}

function httpJson(string $url, string $method, array $headers, ?array $payload): array
{
    $headerLines = array_merge(['Accept: application/json'], $headers);
    $body = null;

    if ($payload !== null) {
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
        $headerLines[] = 'Content-Type: application/json';
    }

    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headerLines,
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_TIMEOUT => 30,
    ]);
    $raw = curl_exec($curl);
    $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $error = curl_error($curl);
    curl_close($curl);

    if ($raw === false || $error !== '') {
        throw new RuntimeException('HTTP request failed: '.$error);
    }

    $decoded = json_decode((string) $raw, true);

    return [
        'status' => $status,
        'json' => is_array($decoded) ? $decoded : ['raw' => (string) $raw],
    ];
}

function safeHeaderSummary(array $headers): array
{
    $summary = [];
    foreach ($headers as $header) {
        [$key, $value] = array_map('trim', explode(':', $header, 2));
        $summary[strtolower($key)] = $value;
    }

    return $summary;
}

function summarize(mixed $value): array
{
    if (! is_array($value)) {
        return ['type' => gettype($value)];
    }

    if (array_key_exists('data', $value) && is_array($value['data'])) {
        $data = $value['data'];
        $items = array_is_list($data) ? $data : ($data['items'] ?? null);
        if (is_array($items) && array_is_list($items)) {
            return [
                'shape' => 'list',
                'count' => count($items),
                'first_id' => $items[0]['id'] ?? null,
                'first_status' => $items[0]['status'] ?? null,
                'meta' => $value['meta'] ?? $data['meta'] ?? null,
            ];
        }
    }

    $root = array_key_exists('data', $value) && is_array($value['data']) ? $value['data'] : $value;

    return [
        'shape' => 'object',
        'keys' => array_slice(array_keys($root), 0, 12),
        'id' => $root['id'] ?? null,
        'tenant_id' => $root['tenant_id'] ?? null,
        'status' => $root['status'] ?? null,
        'kpis' => $root['kpis'] ?? null,
        'totals' => $root['totals'] ?? null,
    ];
}
