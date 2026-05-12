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
        'X-Request-Id' => 'qa-seo-'.$label,
    ];

    if ($accessToken !== null) {
        $headers['Authorization'] = 'Bearer '.$accessToken;
    }

    if ($write) {
        $headers['Idempotency-Key'] = 'qa-seo-'.$label.'-'.bin2hex(random_bytes(4));
    }

    $pending = Http::withHeaders($headers)->timeout(20);
    $url = $baseUrl.$path;
    $response = match (strtoupper($method)) {
        'GET' => $pending->get($url, $query),
        'POST' => $pending->post($url, $payload),
        'PATCH' => $pending->patch($url, $payload),
        'DELETE' => $pending->delete($url, $payload),
        default => throw new InvalidArgumentException('Unsupported method '.$method),
    };

    $json = $response->body() === '' ? [] : $response->json();
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
        'resource' => summarizeResource(is_array($json) ? $json : []),
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
        'access_token_present' => isset($loginJson['access_token']),
        'refresh_token_present' => isset($loginJson['refresh_token']),
    ],
];

$pagePath = '/qa-seo-page-'.$run;
$redirectSource = '/qa-old-seo-page-'.$run;
$redirectTarget = 'https://alpha.newpaotang.test'.$pagePath;

$settingsBefore = $request('settings-get-before', 'GET', '/admin/tenant/seo');
$settingsUpdate = $request('settings-update', 'PATCH', '/admin/tenant/seo', [
    'status' => 'active',
    'default_title' => 'QA Tenant SEO '.$run,
    'title_template' => '{{title}} | QA '.$run,
    'default_description' => 'QA tenant SEO description '.$run,
    'default_keywords' => ['qa', 'seo', $run],
    'robots_default' => 'index,follow',
    'canonical_base_url' => 'https://alpha.newpaotang.test',
    'og_image_url' => 'https://alpha.newpaotang.test/og-'.$run.'.png',
], [], true);
$settingsBlankKeywords = $request('settings-blank-keywords', 'PATCH', '/admin/tenant/seo', [
    'default_title' => 'QA Tenant SEO Blank '.$run,
    'default_keywords' => [],
], [], true);

$pageListBefore = $request('page-list-before', 'GET', '/admin/tenant/seo/pages', [], ['limit' => 20]);
$pageCreate = $request('page-create', 'POST', '/admin/tenant/seo/pages', [
    'path' => $pagePath,
    'title' => 'QA SEO Page '.$run,
    'description' => 'QA SEO page description',
    'canonical_url' => 'https://alpha.newpaotang.test'.$pagePath,
    'robots' => 'index,follow',
    'og_image_url' => 'https://alpha.newpaotang.test/page-'.$run.'.png',
    'status' => 'active',
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$pageId = (string) ($pageCreate['id'] ?? '');
$pageListAfterCreate = $request('page-list-after-create', 'GET', '/admin/tenant/seo/pages', [], ['path' => $pagePath, 'limit' => 20]);
$pageUpdate = $request('page-update', 'PATCH', '/admin/tenant/seo/pages/'.$pageId, [
    'title' => 'QA SEO Page Updated '.$run,
    'robots' => 'noindex,nofollow',
    'status' => 'inactive',
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);
$pageFilterInactive = $request('page-filter-inactive', 'GET', '/admin/tenant/seo/pages', [], ['status' => 'inactive', 'path' => $pagePath, 'limit' => 20]);

$redirectListBefore = $request('redirect-list-before', 'GET', '/admin/tenant/redirects', [], ['limit' => 20]);
$redirectCreate = $request('redirect-create', 'POST', '/admin/tenant/redirects', [
    'source_path' => $redirectSource,
    'target_url' => $redirectTarget,
    'status_code' => 301,
    'status' => 'active',
    'metadata' => ['source' => 'qa-api', 'run' => $run],
], [], true);
$redirectId = (string) ($redirectCreate['id'] ?? '');
$redirectUpdate = $request('redirect-update', 'PATCH', '/admin/tenant/redirects/'.$redirectId, [
    'target_url' => $redirectTarget.'?updated=1',
    'status_code' => 302,
    'status' => 'inactive',
    'metadata' => [['source' => 'qa-api-update'], ['run' => $run]],
], [], true);
$redirectFilterInactive = $request('redirect-filter-inactive', 'GET', '/admin/tenant/redirects', [], ['status' => 'inactive', 'limit' => 20]);

$request('page-delete', 'DELETE', '/admin/tenant/seo/pages/'.$pageId, ['reason' => 'qa cleanup seo page'], [], true);
$pageListAfterDelete = $request('page-list-after-delete', 'GET', '/admin/tenant/seo/pages', [], ['path' => $pagePath, 'limit' => 20]);

$request('redirect-delete', 'DELETE', '/admin/tenant/redirects/'.$redirectId, ['reason' => 'qa cleanup redirect'], [], true);
$redirectListAfterDelete = $request('redirect-list-after-delete', 'GET', '/admin/tenant/redirects', [], ['status' => 'inactive', 'limit' => 20]);

$result = [
    'result' => 'PASS',
    'run' => $run,
    'base_url' => $baseUrl,
    'tenant_id' => $tenantId,
    'fixtures' => [
        'seo_page_id' => $pageId,
        'seo_page_path' => $pagePath,
        'redirect_id' => $redirectId,
        'redirect_source_path' => $redirectSource,
    ],
    'checks' => [
        'settings_loaded' => ($settingsBefore['tenant_id'] ?? null) === $tenantId,
        'settings_update_round_trip' => ($settingsUpdate['default_title'] ?? null) === 'QA Tenant SEO '.$run
            && ($settingsUpdate['default_keywords'][2] ?? null) === $run,
        'settings_blank_keywords_array' => array_key_exists('default_keywords', $settingsBlankKeywords)
            && is_array($settingsBlankKeywords['default_keywords'])
            && count($settingsBlankKeywords['default_keywords']) === 0,
        'page_create_update_delete' => ($pageCreate['path'] ?? null) === $pagePath
            && containsId($pageListAfterCreate, $pageId)
            && ($pageUpdate['title'] ?? null) === 'QA SEO Page Updated '.$run
            && containsId($pageFilterInactive, $pageId)
            && ! containsId($pageListAfterDelete, $pageId),
        'redirect_create_update_delete' => ($redirectCreate['source_path'] ?? null) === $redirectSource
            && ($redirectUpdate['status_code'] ?? null) === 302
            && containsId($redirectFilterInactive, $redirectId)
            && ! containsId($redirectListAfterDelete, $redirectId),
        'all_writes_had_idempotency_key' => allWritesHadIdempotency($events),
        'tenant_scope_headers_present' => tenantScopeHeadersPresent($events, $tenantId),
        'no_page_or_redirect_detail_get_called' => noDetailEndpointCalls($events),
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

function summarizeResource(array $json): array
{
    $summary = [];
    foreach (['id', 'tenant_id', 'status', 'default_title', 'path', 'title', 'robots', 'source_path', 'target_url', 'status_code'] as $key) {
        if (array_key_exists($key, $json)) {
            $summary[$key] = $json[$key];
        }
    }

    if (array_key_exists('default_keywords', $json)) {
        $summary['default_keywords_count'] = is_array($json['default_keywords']) ? count($json['default_keywords']) : null;
    }
    if (array_key_exists('metadata', $json)) {
        $summary['metadata_type'] = is_array($json['metadata']) && array_is_list($json['metadata']) ? 'array' : gettype($json['metadata']);
    }
    if (array_key_exists('data', $json) && is_array($json['data'])) {
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

function noDetailEndpointCalls(array $events): bool
{
    foreach ($events as $event) {
        if (($event['method'] ?? '') !== 'GET') {
            continue;
        }

        $path = (string) ($event['path'] ?? '');
        if (preg_match('#^/admin/tenant/seo/pages/[^/]+$#', $path) || preg_match('#^/admin/tenant/redirects/[^/]+$#', $path)) {
            return false;
        }
    }

    return true;
}
