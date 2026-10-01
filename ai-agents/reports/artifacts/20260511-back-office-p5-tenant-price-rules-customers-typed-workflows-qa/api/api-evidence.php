<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

chdir('/var/www/html');

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$apiBase = getenv('QA_API_BASE') ?: 'http://platform-api:8000/api/v1';
$tenantId = 'ten_demo_alpha';
$run = strtolower(Str::ulid()->toBase32());
$gameId = DB::table('games')->orderBy('id')->value('id');

$login = Http::baseUrl($apiBase)
    ->acceptJson()
    ->asJson()
    ->post('/auth/admin/login', [
        'email' => 'owner@alpha.newpaotang.test',
        'password' => (string) config('platform.seed.tenant_owner_password'),
        'scope' => 'tenant',
        'tenant_id' => $tenantId,
    ]);

if (! $login->successful()) {
    fwrite(STDERR, "tenant admin login failed: ".$login->status().PHP_EOL);
    exit(1);
}

$token = (string) $login->json('access_token');
$headers = [
    'X-Admin-Scope' => 'tenant',
    'X-Tenant-Id' => $tenantId,
];

$events = [];

$record = function (
    string $label,
    string $method,
    string $path,
    array $headers,
    array $payloadKeys,
    Illuminate\Http\Client\Response $response,
    array $checks = []
) use (&$events): void {
    $events[] = [
        'label' => $label,
        'method' => $method,
        'path' => $path,
        'status' => $response->status(),
        'headers' => [
            'x_admin_scope' => $headers['X-Admin-Scope'] ?? null,
            'x_tenant_id' => $headers['X-Tenant-Id'] ?? null,
            'idempotency_key_present' => array_key_exists('Idempotency-Key', $headers),
        ],
        'payload_keys' => $payloadKeys,
        'checks' => $checks,
    ];
};

$client = fn (array $extraHeaders = []) => Http::baseUrl($apiBase)
    ->acceptJson()
    ->asJson()
    ->withToken($token)
    ->withHeaders($headers + $extraHeaders);

$priceCreatePayload = [
    'code' => 'p5_price_rule_'.$run,
    'name' => 'P5 Price Rule '.$run,
    'game_id' => $gameId,
    'rule_type' => 'fixed_price',
    'price_amount' => 12345,
    'currency' => 'THB',
    'conditions' => ['qa_run' => $run, 'segment' => 'safe_local'],
    'status' => 'active',
];
$priceCreateHeaders = ['Idempotency-Key' => 'qa-price-create-'.$run];
$priceCreate = $client($priceCreateHeaders)->post('/admin/tenant/price-rules', $priceCreatePayload);
$priceRuleId = (string) $priceCreate->json('id');
$record('price-rule-create', 'POST', '/admin/tenant/price-rules', $headers + $priceCreateHeaders, array_keys($priceCreatePayload), $priceCreate, [
    'tenant_id_matches' => $priceCreate->json('tenant_id') === $tenantId,
    'id_present' => $priceRuleId !== '',
    'game_id_used' => $gameId !== null,
    'conditions_round_trip' => $priceCreate->json('conditions.qa_run') === $run,
]);

$priceDetail = $client()->get('/admin/tenant/price-rules/'.$priceRuleId);
$record('price-rule-detail-after-create', 'GET', '/admin/tenant/price-rules/{price_rule_id}', $headers, [], $priceDetail, [
    'id_matches' => $priceDetail->json('id') === $priceRuleId,
    'code_matches' => $priceDetail->json('code') === $priceCreatePayload['code'],
]);

$priceUpdatePayload = [
    'name' => 'P5 Price Rule Updated '.$run,
    'rule_type' => 'fixed_price',
    'price_amount' => 23456,
    'currency' => 'THB',
    'conditions' => [['qa_run' => $run, 'tier' => 'updated']],
    'status' => 'active',
];
$priceUpdateHeaders = ['Idempotency-Key' => 'qa-price-update-'.$run];
$priceUpdate = $client($priceUpdateHeaders)->patch('/admin/tenant/price-rules/'.$priceRuleId, $priceUpdatePayload);
$record('price-rule-update', 'PATCH', '/admin/tenant/price-rules/{price_rule_id}', $headers + $priceUpdateHeaders, array_keys($priceUpdatePayload), $priceUpdate, [
    'name_updated' => $priceUpdate->json('name') === $priceUpdatePayload['name'],
    'price_amount_updated' => $priceUpdate->json('price.amount') === 23456,
    'conditions_array_round_trip' => is_array($priceUpdate->json('conditions')) && array_is_list($priceUpdate->json('conditions')),
]);

$priceList = $client()->get('/admin/tenant/price-rules', ['status' => 'active']);
$record('price-rule-list-filter-active', 'GET', '/admin/tenant/price-rules?status=active', $headers, [], $priceList, [
    'created_rule_found' => collect($priceList->json('data') ?? [])->contains(fn ($row): bool => ($row['id'] ?? null) === $priceRuleId),
    'cursor_meta_present' => is_array($priceList->json('meta')),
]);

$priceArchivePayload = ['reason' => 'QA safe local archive '.$run];
$priceArchiveHeaders = ['Idempotency-Key' => 'qa-price-archive-'.$run];
$priceArchive = $client($priceArchiveHeaders)->send('DELETE', '/admin/tenant/price-rules/'.$priceRuleId, [
    'json' => $priceArchivePayload,
]);
$record('price-rule-archive', 'DELETE', '/admin/tenant/price-rules/{price_rule_id}', $headers + $priceArchiveHeaders, array_keys($priceArchivePayload), $priceArchive, [
    'no_content' => $priceArchive->status() === 204,
]);

$priceArchivedDetail = $client()->get('/admin/tenant/price-rules/'.$priceRuleId);
$record('price-rule-detail-after-archive', 'GET', '/admin/tenant/price-rules/{price_rule_id}', $headers, [], $priceArchivedDetail, [
    'status_archived' => $priceArchivedDetail->json('status') === 'archived',
]);

$memberCreatePayload = [
    'name' => 'P5 QA Member '.$run,
    'phone' => '08'.random_int(10000000, 99999999),
    'email' => 'p5.qa.'.$run.'@example.test',
    'password' => bin2hex(random_bytes(12)),
    'status' => 'active',
    'send_invitation' => false,
];
$memberCreateHeaders = ['Idempotency-Key' => 'qa-member-create-'.$run];
$memberCreate = $client($memberCreateHeaders)->post('/admin/tenant/members', $memberCreatePayload);
$memberId = (string) $memberCreate->json('id');
$memberCreateBody = json_encode($memberCreate->json(), JSON_THROW_ON_ERROR);
$record('member-create', 'POST', '/admin/tenant/members', $headers + $memberCreateHeaders, array_keys($memberCreatePayload), $memberCreate, [
    'tenant_id_matches' => $memberCreate->json('tenant_id') === $tenantId,
    'id_present' => $memberId !== '',
    'password_hash_absent' => ! str_contains($memberCreateBody, 'password_hash'),
]);
unset($memberCreatePayload['password']);

$memberDetail = $client()->get('/admin/tenant/members/'.$memberId);
$record('member-detail-after-create', 'GET', '/admin/tenant/members/{member_id}', $headers, [], $memberDetail, [
    'id_matches' => $memberDetail->json('id') === $memberId,
    'phone_matches' => $memberDetail->json('phone') === $memberCreatePayload['phone'],
    'password_hash_absent' => ! str_contains(json_encode($memberDetail->json(), JSON_THROW_ON_ERROR), 'password_hash'),
]);

$memberUpdatePayload = [
    'name' => 'P5 QA Member Updated '.$run,
    'phone' => $memberCreatePayload['phone'],
    'email' => 'p5.qa.updated.'.$run.'@example.test',
    'admin_note' => 'QA audit note '.$run,
];
$memberUpdateHeaders = ['Idempotency-Key' => 'qa-member-update-'.$run];
$memberUpdate = $client($memberUpdateHeaders)->patch('/admin/tenant/members/'.$memberId, $memberUpdatePayload);
$record('member-update', 'PATCH', '/admin/tenant/members/{member_id}', $headers + $memberUpdateHeaders, array_keys($memberUpdatePayload), $memberUpdate, [
    'name_updated' => $memberUpdate->json('name') === $memberUpdatePayload['name'],
    'email_updated' => $memberUpdate->json('email') === $memberUpdatePayload['email'],
]);

$memberStatusPayload = [
    'status' => 'suspended',
    'notify_member' => false,
    'reason' => 'QA safe local status change '.$run,
];
$memberStatusHeaders = ['Idempotency-Key' => 'qa-member-status-'.$run];
$memberStatus = $client($memberStatusHeaders)->post('/admin/tenant/members/'.$memberId.'/status', $memberStatusPayload);
$record('member-status-change', 'POST', '/admin/tenant/members/{member_id}/status', $headers + $memberStatusHeaders, array_keys($memberStatusPayload), $memberStatus, [
    'status_suspended' => $memberStatus->json('status') === 'suspended',
]);

$memberList = $client()->get('/admin/tenant/members', ['status' => 'suspended', 'q' => $memberUpdatePayload['email']]);
$record('member-list-filter-suspended', 'GET', '/admin/tenant/members?status=suspended&q={email}', $headers, [], $memberList, [
    'updated_member_found' => collect($memberList->json('data') ?? [])->contains(fn ($row): bool => ($row['id'] ?? null) === $memberId),
    'cursor_meta_present' => is_array($memberList->json('meta')),
    'password_hash_absent' => ! str_contains(json_encode($memberList->json(), JSON_THROW_ON_ERROR), 'password_hash'),
]);

echo json_encode([
    'generated_at' => now()->toIso8601String(),
    'api_base' => $apiBase,
    'scope' => 'tenant',
    'tenant_id' => $tenantId,
    'run_id' => $run,
    'safe_fixture_ids' => [
        'price_rule_id' => $priceRuleId,
        'member_id' => $memberId,
        'game_id' => $gameId,
    ],
    'events' => $events,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
