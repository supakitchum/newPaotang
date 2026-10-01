<?php

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

chdir('/var/www/html');

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$apiBase = getenv('QA_API_BASE') ?: 'http://platform-api:8000/api/v1';
$tenantId = 'ten_demo_alpha';
$run = strtolower(Str::ulid()->toBase32());

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

$agentCreatePayload = [
    'code' => 'p5_agent_'.$run,
    'name' => 'P5 Agent '.$run,
    'phone' => '08'.random_int(10000000, 99999999),
    'email' => 'p5.agent.'.$run.'@example.test',
    'store_id' => 'qa-store-'.$run,
    'status' => 'active',
    'metadata' => ['qa_run' => $run, 'source' => 'api'],
];
$agentCreateHeaders = ['Idempotency-Key' => 'qa-agent-create-'.$run];
$agentCreate = $client($agentCreateHeaders)->post('/admin/tenant/agents', $agentCreatePayload);
$agentId = (string) $agentCreate->json('id');
$record('agent-create', 'POST', '/admin/tenant/agents', $headers + $agentCreateHeaders, array_keys($agentCreatePayload), $agentCreate, [
    'tenant_id_matches' => $agentCreate->json('tenant_id') === $tenantId,
    'id_present' => $agentId !== '',
    'metadata_round_trip' => $agentCreate->json('metadata.qa_run') === $run,
]);

$agentDetail = $client()->get('/admin/tenant/agents/'.$agentId);
$record('agent-detail-after-create', 'GET', '/admin/tenant/agents/{agent_id}', $headers, [], $agentDetail, [
    'id_matches' => $agentDetail->json('id') === $agentId,
    'code_matches' => $agentDetail->json('code') === $agentCreatePayload['code'],
    'quotas_array_present' => is_array($agentDetail->json('quotas')),
]);

$agentUpdatePayload = [
    'code' => 'p5_agent_updated_'.$run,
    'name' => 'P5 Agent Updated '.$run,
    'phone' => $agentCreatePayload['phone'],
    'email' => 'p5.agent.updated.'.$run.'@example.test',
    'store_id' => 'qa-store-updated-'.$run,
    'status' => 'inactive',
    'metadata' => [['qa_run' => $run, 'stage' => 'updated']],
];
$agentUpdateHeaders = ['Idempotency-Key' => 'qa-agent-update-'.$run];
$agentUpdate = $client($agentUpdateHeaders)->patch('/admin/tenant/agents/'.$agentId, $agentUpdatePayload);
$record('agent-update', 'PATCH', '/admin/tenant/agents/{agent_id}', $headers + $agentUpdateHeaders, array_keys($agentUpdatePayload), $agentUpdate, [
    'code_updated' => $agentUpdate->json('code') === $agentUpdatePayload['code'],
    'name_updated' => $agentUpdate->json('name') === $agentUpdatePayload['name'],
    'metadata_array_round_trip' => is_array($agentUpdate->json('metadata')) && array_is_list($agentUpdate->json('metadata')),
]);

$agentList = $client()->get('/admin/tenant/agents', ['status' => 'inactive']);
$record('agent-list-filter-inactive', 'GET', '/admin/tenant/agents?status=inactive', $headers, [], $agentList, [
    'updated_agent_found' => collect($agentList->json('data') ?? [])->contains(fn ($row): bool => ($row['id'] ?? null) === $agentId),
    'cursor_meta_present' => is_array($agentList->json('meta')),
]);

$quotaPayload = [
    'game_id' => null,
    'quota_count' => 15,
    'used_count' => 3,
    'status' => 'active',
    'payload' => ['qa_run' => $run, 'route' => 'agents'],
    'reason' => 'QA safe local agent route quota update '.$run,
];
$quotaHeaders = ['Idempotency-Key' => 'qa-agent-quota-'.$run];
$quotaUpdate = $client($quotaHeaders)->patch('/admin/tenant/agents/'.$agentId.'/quotas', $quotaPayload);
$record('agent-route-quota-update', 'PATCH', '/admin/tenant/agents/{agent_id}/quotas', $headers + $quotaHeaders, array_keys($quotaPayload), $quotaUpdate, [
    'quota_count_updated' => $quotaUpdate->json('quotas.0.quota_count') === 15,
    'used_count_updated' => $quotaUpdate->json('quotas.0.used_count') === 3,
    'payload_round_trip' => $quotaUpdate->json('quotas.0.payload.qa_run') === $run,
]);

$quotaDetail = $client()->get('/admin/tenant/agents/'.$agentId);
$record('agent-detail-after-agent-route-quota', 'GET', '/admin/tenant/agents/{agent_id}', $headers, [], $quotaDetail, [
    'quota_count_visible' => $quotaDetail->json('quotas.0.quota_count') === 15,
]);

$dedicatedQuotaPayload = [
    'game_id' => null,
    'quota_count' => 20,
    'used_count' => 4,
    'status' => 'suspended',
    'payload' => [['qa_run' => $run, 'route' => 'agent_quotas']],
    'reason' => 'QA safe local dedicated quota route update '.$run,
];
$dedicatedQuotaHeaders = ['Idempotency-Key' => 'qa-dedicated-quota-'.$run];
$dedicatedQuotaUpdate = $client($dedicatedQuotaHeaders)->patch('/admin/tenant/agents/'.$agentId.'/quotas', $dedicatedQuotaPayload);
$record('dedicated-agent-quota-update', 'PATCH', '/admin/tenant/agents/{agent_id}/quotas', $headers + $dedicatedQuotaHeaders, array_keys($dedicatedQuotaPayload), $dedicatedQuotaUpdate, [
    'quota_count_updated' => $dedicatedQuotaUpdate->json('quotas.0.quota_count') === 20,
    'used_count_updated' => $dedicatedQuotaUpdate->json('quotas.0.used_count') === 4,
    'status_updated' => $dedicatedQuotaUpdate->json('quotas.0.status') === 'suspended',
    'payload_array_round_trip' => is_array($dedicatedQuotaUpdate->json('quotas.0.payload')) && array_is_list($dedicatedQuotaUpdate->json('quotas.0.payload')),
]);

$dedicatedDetail = $client()->get('/admin/tenant/agents/'.$agentId);
$record('agent-detail-after-dedicated-quota', 'GET', '/admin/tenant/agents/{agent_id}', $headers, [], $dedicatedDetail, [
    'quota_status_visible' => $dedicatedDetail->json('quotas.0.status') === 'suspended',
    'quota_count_visible' => $dedicatedDetail->json('quotas.0.quota_count') === 20,
]);

echo json_encode([
    'generated_at' => now()->toIso8601String(),
    'api_base' => $apiBase,
    'scope' => 'tenant',
    'tenant_id' => $tenantId,
    'run_id' => $run,
    'safe_fixture_ids' => [
        'agent_id' => $agentId,
    ],
    'events' => $events,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
