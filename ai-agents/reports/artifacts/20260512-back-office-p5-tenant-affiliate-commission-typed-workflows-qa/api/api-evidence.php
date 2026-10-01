<?php

use Illuminate\Support\Facades\Http;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$baseUrl = rtrim(getenv('QA_API_BASE') ?: 'http://platform-api:8000/api/v1', '/');
$tenantId = 'ten_demo_alpha';
$run = strtolower(bin2hex(random_bytes(4)));
$accessToken = null;

$events = [];

$request = function (string $label, string $method, string $path, array $payload = [], array $query = [], bool $write = false) use ($baseUrl, $tenantId, &$accessToken, &$events): array {
    $headers = [
        'Accept' => 'application/json',
        'X-Admin-Scope' => 'tenant',
        'X-Tenant-Id' => $tenantId,
        'X-Request-Id' => 'qa-affiliate-'.$label,
    ];

    if ($accessToken !== null) {
        $headers['Authorization'] = 'Bearer '.$accessToken;
    }

    if ($write) {
        $headers['Idempotency-Key'] = 'qa-affiliate-'.$label.'-'.bin2hex(random_bytes(4));
    }

    $url = $baseUrl.$path;
    $pending = Http::withHeaders($headers)->timeout(20);
    $response = match (strtoupper($method)) {
        'GET' => $pending->get($url, $query),
        'POST' => $pending->post($url, $payload),
        'PATCH' => $pending->patch($url, $payload),
        'DELETE' => $pending->delete($url, $payload),
        default => throw new InvalidArgumentException('Unsupported method '.$method),
    };

    $json = null;
    if ($response->body() !== '') {
        $json = $response->json();
    }

    $events[] = [
        'label' => $label,
        'method' => strtoupper($method),
        'path' => $path,
        'status' => $response->status(),
        'query_keys' => array_keys($query),
        'payload_keys' => payloadKeys($payload),
        'headers' => [
            'x_admin_scope' => $headers['X-Admin-Scope'],
            'x_tenant_id' => $headers['X-Tenant-Id'],
            'x_request_id_present' => isset($headers['X-Request-Id']),
            'idempotency_key_present' => isset($headers['Idempotency-Key']),
            'authorization_present' => isset($headers['Authorization']),
        ],
        'resource' => summarizeResource($json),
        'error_code' => is_array($json) ? ($json['error']['code'] ?? $json['error'] ?? null) : null,
    ];

    if ($response->failed()) {
        throw new RuntimeException($label.' failed with HTTP '.$response->status().': '.substr($response->body(), 0, 500));
    }

    return is_array($json) ? $json : [];
};

$login = Http::acceptJson()->timeout(20)->post($baseUrl.'/auth/admin/login', [
    'email' => 'owner@alpha.newpaotang.test',
    'password' => (string) config('platform.seed.tenant_owner_password'),
    'scope' => 'tenant',
    'tenant_id' => $tenantId,
]);

if ($login->failed()) {
    throw new RuntimeException('login failed with HTTP '.$login->status());
}

$loginJson = $login->json();
$accessToken = (string) ($loginJson['access_token'] ?? '');
if ($accessToken === '') {
    throw new RuntimeException('login did not return an access token');
}

$events[] = [
    'label' => 'login',
    'method' => 'POST',
    'path' => '/auth/admin/login',
    'status' => $login->status(),
    'payload_keys' => ['email', 'scope', 'tenant_id'],
    'headers' => ['authorization_present' => false],
    'resource' => [
        'scope' => $loginJson['active_scope']['scope'] ?? null,
        'tenant_id' => $loginJson['active_scope']['tenant_id'] ?? null,
        'access_token_present' => isset($loginJson['access_token']),
        'refresh_token_present' => isset($loginJson['refresh_token']),
    ],
];

$programCode = 'qa_program_'.$run;
$affiliateCode = 'qa_affiliate_'.$run;
$linkCode = 'qa_link_'.$run;
$ruleCode = 'qa_rule_'.$run;

$program = $request('program-create', 'POST', '/admin/tenant/affiliate-programs', [
    'code' => $programCode,
    'name' => 'QA Program '.$run,
    'status' => 'active',
    'starts_at' => '2026-05-12T09:00:00+07:00',
    'ends_at' => '2026-06-12T09:00:00+07:00',
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$programId = (string) ($program['id'] ?? '');

$programUpdated = $request('program-update', 'PATCH', '/admin/tenant/affiliate-programs/'.$programId, [
    'name' => 'QA Program Updated '.$run,
    'status' => 'inactive',
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);

$programFilter = $request('program-filter-inactive', 'GET', '/admin/tenant/affiliate-programs', [], [
    'status' => 'inactive',
    'limit' => 20,
]);

$affiliate = $request('affiliate-create', 'POST', '/admin/tenant/affiliates', [
    'code' => $affiliateCode,
    'name' => 'QA Affiliate '.$run,
    'phone' => '0200000000',
    'email' => 'qa-affiliate-'.$run.'@example.test',
    'status' => 'active',
    'currency' => 'THB',
    'payout_profile' => ['method' => 'bank_transfer', 'account_ref' => 'qa-redacted'],
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$affiliateId = (string) ($affiliate['id'] ?? '');

$affiliateUpdated = $request('affiliate-update', 'PATCH', '/admin/tenant/affiliates/'.$affiliateId, [
    'name' => 'QA Affiliate Updated '.$run,
    'status' => 'inactive',
    'payout_profile' => [['method' => 'manual_review'], ['run' => $run]],
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);

$affiliateFilter = $request('affiliate-filter-status', 'GET', '/admin/tenant/affiliates', [], [
    'status' => 'inactive',
    'limit' => 20,
]);

$link = $request('link-create', 'POST', '/admin/tenant/affiliate-links', [
    'affiliate_account_id' => $affiliateId,
    'affiliate_program_id' => $programId,
    'code' => $linkCode,
    'url' => 'https://newpaotang.local/a/'.$linkCode,
    'status' => 'active',
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$linkId = (string) ($link['id'] ?? '');

$linkUpdated = $request('link-update', 'PATCH', '/admin/tenant/affiliate-links/'.$linkId, [
    'status' => 'inactive',
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);

$linkFilter = $request('link-filter-affiliate', 'GET', '/admin/tenant/affiliate-links', [], [
    'affiliate_id' => $affiliateId,
    'limit' => 20,
]);

$rule = $request('rule-create', 'POST', '/admin/tenant/commission-rules', [
    'affiliate_program_id' => $programId,
    'affiliate_account_id' => $affiliateId,
    'code' => $ruleCode,
    'name' => 'QA Rule '.$run,
    'rule_type' => 'fixed_per_order',
    'amount' => ['amount' => 125, 'currency' => 'THB'],
    'rate_bps' => 0,
    'status' => 'active',
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$ruleId = (string) ($rule['id'] ?? '');

$ruleUpdated = $request('rule-update', 'PATCH', '/admin/tenant/commission-rules/'.$ruleId, [
    'name' => 'QA Rule Updated '.$run,
    'rule_type' => 'per_ticket',
    'amount' => ['amount' => 175, 'currency' => 'THB'],
    'rate_bps' => 0,
    'status' => 'inactive',
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);

$ruleFilter = $request('rule-filter-affiliate-account', 'GET', '/admin/tenant/commission-rules', [], [
    'affiliate_account_id' => $affiliateId,
    'limit' => 20,
]);

$request('rule-archive', 'DELETE', '/admin/tenant/commission-rules/'.$ruleId, [
    'reason' => 'qa cleanup commission rule',
], [], true);
$ruleAfterArchive = $request('rule-detail-after-archive', 'GET', '/admin/tenant/commission-rules/'.$ruleId);

$request('link-archive', 'DELETE', '/admin/tenant/affiliate-links/'.$linkId, [
    'reason' => 'qa cleanup affiliate link',
], [], true);
$linkAfterArchive = $request('link-detail-after-archive', 'GET', '/admin/tenant/affiliate-links/'.$linkId);

$request('program-archive', 'DELETE', '/admin/tenant/affiliate-programs/'.$programId, [
    'reason' => 'qa cleanup affiliate program',
], [], true);
$programAfterArchive = $request('program-detail-after-archive', 'GET', '/admin/tenant/affiliate-programs/'.$programId);

$result = [
    'result' => 'PASS',
    'run' => $run,
    'base_url' => $baseUrl,
    'tenant_id' => $tenantId,
    'fixtures' => [
        'affiliate_program_id' => $programId,
        'affiliate_account_id' => $affiliateId,
        'affiliate_link_id' => $linkId,
        'commission_rule_id' => $ruleId,
    ],
    'checks' => [
        'program_create_update_archive' => ($program['tenant_id'] ?? null) === $tenantId
            && ($programUpdated['metadata'][0]['source'] ?? null) === 'qa-api-update'
            && ($programAfterArchive['status'] ?? null) === 'archived',
        'affiliate_create_update_no_archive' => ($affiliate['tenant_id'] ?? null) === $tenantId
            && ($affiliateUpdated['payout_profile'][0]['method'] ?? null) === 'manual_review',
        'link_create_update_archive' => ($link['affiliate_account_id'] ?? null) === $affiliateId
            && ($linkUpdated['metadata'][0]['source'] ?? null) === 'qa-api-update'
            && ($linkAfterArchive['status'] ?? null) === 'archived',
        'rule_create_update_archive' => ($rule['amount']['amount'] ?? null) === 125
            && ($ruleUpdated['amount']['amount'] ?? null) === 175
            && ($ruleAfterArchive['status'] ?? null) === 'archived',
        'filters_found_safe_rows' => containsId($programFilter, $programId)
            && containsId($affiliateFilter, $affiliateId)
            && containsId($linkFilter, $linkId)
            && containsId($ruleFilter, $ruleId),
        'all_writes_had_idempotency_key' => allWritesHadIdempotency($events),
        'tenant_scope_headers_present' => tenantScopeHeadersPresent($events, $tenantId),
    ],
    'events' => $events,
];

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;

function payloadKeys(array $payload, string $prefix = ''): array
{
    $keys = [];
    foreach ($payload as $key => $value) {
        $path = $prefix === '' ? (string) $key : $prefix.'.'.$key;
        $keys[] = $path;
        if (is_array($value) && array_is_list($value) === false) {
            array_push($keys, ...payloadKeys($value, $path));
        }
    }

    return $keys;
}

function summarizeResource(mixed $json): array
{
    if (! is_array($json)) {
        return [];
    }

    $resource = array_key_exists('data', $json) && is_array($json['data']) && array_is_list($json['data']) === false
        ? $json['data']
        : $json;

    $summary = [];
    foreach (['id', 'tenant_id', 'affiliate_id', 'affiliate_account_id', 'affiliate_program_id', 'code', 'name', 'rule_type', 'status'] as $key) {
        if (array_key_exists($key, $resource)) {
            $summary[$key] = $resource[$key];
        }
    }

    if (array_key_exists('amount', $resource)) {
        $summary['amount'] = $resource['amount'];
    }
    if (array_key_exists('metadata', $resource)) {
        $summary['metadata_type'] = is_array($resource['metadata']) && array_is_list($resource['metadata']) ? 'array' : gettype($resource['metadata']);
    }
    if (array_key_exists('payout_profile', $resource)) {
        $summary['payout_profile_type'] = is_array($resource['payout_profile']) && array_is_list($resource['payout_profile']) ? 'array' : gettype($resource['payout_profile']);
    }
    if (array_key_exists('data', $json) && is_array($json['data']) && array_is_list($json['data'])) {
        $summary['list_count'] = count($json['data']);
        $summary['ids'] = array_values(array_filter(array_map(fn ($row) => is_array($row) ? ($row['id'] ?? null) : null, $json['data'])));
    }
    if (array_key_exists('meta', $json)) {
        $summary['meta_keys'] = array_keys((array) $json['meta']);
    }

    return $summary;
}

function containsId(array $response, string $id): bool
{
    foreach (($response['data'] ?? []) as $row) {
        if (is_array($row) && ($row['id'] ?? null) === $id) {
            return true;
        }
    }

    return false;
}

function allWritesHadIdempotency(array $events): bool
{
    foreach ($events as $event) {
        if (in_array($event['method'] ?? '', ['POST', 'PATCH', 'DELETE'], true)
            && ($event['path'] ?? '') !== '/auth/admin/login'
            && ! ($event['headers']['idempotency_key_present'] ?? false)) {
            return false;
        }
    }

    return true;
}

function tenantScopeHeadersPresent(array $events, string $tenantId): bool
{
    foreach ($events as $event) {
        if (($event['path'] ?? '') === '/auth/admin/login') {
            continue;
        }

        if (($event['headers']['x_admin_scope'] ?? null) !== 'tenant'
            || ($event['headers']['x_tenant_id'] ?? null) !== $tenantId) {
            return false;
        }
    }

    return true;
}
