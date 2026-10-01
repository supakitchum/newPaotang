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

$gameId = DB::table('games')->orderBy('id')->value('id') ?: 'gam_p5_ticket_filter';
if (! DB::table('games')->where('id', $gameId)->exists()) {
    DB::table('games')->insert([
        'id' => $gameId,
        'code' => 'p5-ticket-filter',
        'name' => 'P5 Ticket Filter Game',
        'draw_at' => $now->copy()->addDays(7),
        'close_at' => $now->copy()->addDays(6),
        'status' => 'open',
        'metadata_json' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);
}

$fixture = [
    'customer_id' => 'cus_p5_ticket_filter',
    'stock_item_id' => 'stk_p5_ticket_filter',
    'local_stock_item_id' => 'lsi_p5_ticket_filter',
    'reservation_id' => 'res_p5_ticket_filter',
    'order_id' => 'ord_p5_ticket_filter',
    'ticket_id' => 'tic_p5_read',
];

DB::transaction(function () use ($fixture, $tenantId, $partnerId, $gameId, $now): void {
    DB::table('customers')->updateOrInsert(['id' => $fixture['customer_id']], [
        'tenant_id' => $tenantId,
        'phone' => '0800000511',
        'email' => 'p5-ticket-filter@example.test',
        'password_hash' => null,
        'avatar_url' => null,
        'name' => 'P5 Ticket Filter Customer',
        'status' => 'active',
        'last_login_at' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('stock_items')->updateOrInsert(['id' => $fixture['stock_item_id']], [
        'game_id' => $gameId,
        'batch_id' => null,
        'full_number' => '951511',
        'front3' => '951',
        'back3' => '511',
        'back2' => '11',
        'status' => 'allocated',
        'partner_id' => $partnerId,
        'tenant_id' => $tenantId,
        'allocation_id' => null,
        'recall_reason' => null,
        'recalled_at' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('local_stock_items')->updateOrInsert(['id' => $fixture['local_stock_item_id']], [
        'tenant_id' => $tenantId,
        'partner_id' => $partnerId,
        'store_id' => 'p5-ticket-filter-store',
        'game_id' => $gameId,
        'stock_item_id' => $fixture['stock_item_id'],
        'allocation_id' => null,
        'full_number' => '951511',
        'front3' => '951',
        'back3' => '511',
        'back2' => '11',
        'image_url' => null,
        'image_thumb_url' => null,
        'status' => 'sold',
        'synced_at' => $now,
        'reserved_at' => $now,
        'sold_at' => $now,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('stock_reservations')->updateOrInsert(['id' => $fixture['reservation_id']], [
        'tenant_id' => $tenantId,
        'customer_id' => $fixture['customer_id'],
        'game_id' => $gameId,
        'status' => 'converted',
        'expires_at' => $now->copy()->addMinutes(15),
        'released_at' => null,
        'cancelled_at' => null,
        'converted_at' => $now,
        'idempotency_key' => 'p5-ticket-filter-reservation',
        'payload_hash' => hash('sha256', 'p5-ticket-filter-reservation'),
        'released_idempotency_key' => null,
        'released_payload_hash' => null,
        'cancelled_idempotency_key' => null,
        'cancelled_payload_hash' => null,
        'cancelled_by_admin_id' => null,
        'cancel_reason' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('stock_reservation_items')->updateOrInsert(
        ['reservation_id' => $fixture['reservation_id'], 'local_stock_item_id' => $fixture['local_stock_item_id']],
        [
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'status' => 'converted',
            'created_at' => $now,
            'updated_at' => $now,
        ],
    );

    DB::table('orders')->updateOrInsert(['id' => $fixture['order_id']], [
        'tenant_id' => $tenantId,
        'customer_id' => $fixture['customer_id'],
        'reservation_id' => $fixture['reservation_id'],
        'game_id' => $gameId,
        'wallet_id' => null,
        'payment_method' => 'wallet',
        'status' => 'paid',
        'payment_status' => 'paid',
        'total_amount' => 8000,
        'currency' => 'THB',
        'reference' => 'P5-TICKET-FILTER',
        'admin_note' => null,
        'idempotency_key' => 'p5-ticket-filter-order',
        'payload_hash' => hash('sha256', 'p5-ticket-filter-order'),
        'paid_at' => $now,
        'cancelled_at' => null,
        'refunded_at' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    DB::table('tickets')->updateOrInsert(['id' => $fixture['ticket_id']], [
        'tenant_id' => $tenantId,
        'customer_id' => $fixture['customer_id'],
        'order_id' => $fixture['order_id'],
        'local_stock_item_id' => $fixture['local_stock_item_id'],
        'game_id' => $gameId,
        'full_number' => '951511',
        'status' => 'active',
        'image_url' => null,
        'image_thumb_url' => null,
        'created_at' => $now,
        'updated_at' => $now,
    ]);
});

$token = login($baseUrl, [
    'email' => 'owner@alpha.newpaotang.test',
    'password' => (string) config('platform.seed.tenant_owner_password'),
    'scope' => 'tenant',
    'tenant_id' => $tenantId,
], ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId]);

$headers = ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId];
$steps = [
    capture('tenant tickets list', $baseUrl, '/admin/tenant/tickets?limit=20', $token, $headers),
    capture('tenant tickets active filter', $baseUrl, '/admin/tenant/tickets?status=active&limit=20', $token, $headers),
    capture('tenant tickets active cursor', $baseUrl, '/admin/tenant/tickets?status=active&cursor=tic_p5_read&limit=20', $token, $headers),
    capture('tenant ticket detail', $baseUrl, '/admin/tenant/tickets/'.$fixture['ticket_id'], $token, $headers),
    capture('tenant tickets closed empty', $baseUrl, '/admin/tenant/tickets?status=closed&limit=20', $token, $headers),
];

echo json_encode([
    'generated_at' => now()->toIso8601String(),
    'base_url' => $baseUrl,
    'fixture' => $fixture + ['tenant_id' => $tenantId, 'partner_id' => $partnerId, 'game_id' => $gameId, 'status' => 'active'],
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

function capture(string $name, string $baseUrl, string $path, string $token, array $scopeHeaders): array
{
    $response = httpJson($baseUrl.$path, 'GET', array_merge($scopeHeaders, ['Authorization: Bearer '.$token]), null);

    return [
        'name' => $name,
        'method' => 'GET',
        'path' => $path,
        'status' => $response['status'],
        'request_headers' => safeHeaderSummary($scopeHeaders),
        'summary' => summarize($response['json']),
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

    if (isset($value['data']) && is_array($value['data']) && array_is_list($value['data'])) {
        return [
            'shape' => 'list',
            'count' => count($value['data']),
            'ids' => array_values(array_filter(array_map(fn (array $row): ?string => $row['id'] ?? null, $value['data']))),
            'statuses' => array_values(array_unique(array_filter(array_map(fn (array $row): ?string => $row['status'] ?? null, $value['data'])))),
            'meta' => $value['meta'] ?? null,
        ];
    }

    $root = isset($value['data']) && is_array($value['data']) ? $value['data'] : $value;

    return [
        'shape' => 'object',
        'keys' => array_slice(array_keys($root), 0, 12),
        'id' => $root['id'] ?? null,
        'tenant_id' => $root['tenant_id'] ?? null,
        'status' => $root['status'] ?? null,
        'order_id' => $root['order']['id'] ?? null,
    ];
}
