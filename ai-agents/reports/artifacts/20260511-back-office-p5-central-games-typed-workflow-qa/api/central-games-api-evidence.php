<?php

use Illuminate\Contracts\Console\Kernel;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$baseUrl = rtrim((string) getenv('QA_API_BASE'), '/') ?: 'http://127.0.0.1:8000/api/v1';
$run = substr(strtolower(dechex(time())), -6);
$code = 'p5_games_api_'.$run;
$headers = ['X-Admin-Scope: central'];

$token = login($baseUrl, [
    'email' => (string) config('platform.seed.central_admin_email'),
    'password' => (string) config('platform.seed.central_admin_password'),
    'scope' => 'central',
], $headers);

$drawAt = now()->copy()->addDays(12)->setSecond(0)->toISOString();
$closeAt = now()->copy()->addDays(11)->setSecond(0)->toISOString();
$updatedCloseAt = now()->copy()->addDays(10)->setSecond(0)->toISOString();

$steps = [];
$steps[] = capture('list before create', $baseUrl, 'GET', '/admin/central/games?limit=20', $token, $headers, null);
$create = capture('create draft game', $baseUrl, 'POST', '/admin/central/games', $token, $headers, [
    'code' => $code,
    'name' => 'P5 Games API '.$run,
    'draw_at' => $drawAt,
    'close_at' => $closeAt,
    'status' => 'draft',
], 'api-create-'.$run);
$steps[] = $create;

$gameId = (string) ($create['summary']['id'] ?? '');
if ($gameId === '') {
    throw new RuntimeException('Create did not return a game id.');
}

$steps[] = capture('detail after create', $baseUrl, 'GET', '/admin/central/games/'.$gameId, $token, $headers, null);
$steps[] = capture('update draft to open', $baseUrl, 'PATCH', '/admin/central/games/'.$gameId, $token, $headers, [
    'name' => 'P5 Games API '.$run.' Open',
    'close_at' => $updatedCloseAt,
    'status' => 'open',
], 'api-update-'.$run);
$steps[] = capture('detail after update', $baseUrl, 'GET', '/admin/central/games/'.$gameId, $token, $headers, null);
$steps[] = capture('close game', $baseUrl, 'POST', '/admin/central/games/'.$gameId.'/close', $token, $headers, [
    'reason' => 'p5 games api qa close',
], 'api-close-'.$run);
$steps[] = capture('archive game', $baseUrl, 'POST', '/admin/central/games/'.$gameId.'/archive', $token, $headers, [
    'reason' => 'p5 games api qa archive',
], 'api-archive-'.$run);
$steps[] = capture('detail after archive', $baseUrl, 'GET', '/admin/central/games/'.$gameId, $token, $headers, null);
$steps[] = capture('archived filter', $baseUrl, 'GET', '/admin/central/games?status=archived&limit=20', $token, $headers, null);

echo json_encode([
    'generated_at' => now()->toIso8601String(),
    'base_url' => $baseUrl,
    'fixture' => [
        'code' => $code,
        'game_id' => $gameId,
    ],
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

function capture(string $name, string $baseUrl, string $method, string $path, string $token, array $scopeHeaders, ?array $payload, ?string $idempotencyKey = null): array
{
    $headers = $scopeHeaders;
    if ($idempotencyKey !== null) {
        $headers[] = 'Idempotency-Key: '.$idempotencyKey;
    }

    $response = httpJson($baseUrl.$path, $method, array_merge($headers, ['Authorization: Bearer '.$token]), $payload);

    return [
        'name' => $name,
        'method' => $method,
        'path' => $path,
        'status' => $response['status'],
        'request_headers' => safeHeaderSummary($headers),
        'request_payload_keys' => $payload === null ? [] : array_keys($payload),
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
        $summary[strtolower($key)] = $key === 'Idempotency-Key' ? 'present' : $value;
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
        ];
    }

    $root = isset($value['data']) && is_array($value['data']) ? $value['data'] : $value;

    return [
        'shape' => 'object',
        'id' => $root['id'] ?? null,
        'code' => $root['code'] ?? null,
        'name' => $root['name'] ?? null,
        'status' => $root['status'] ?? null,
        'draw_at' => $root['draw_at'] ?? null,
        'close_at' => $root['close_at'] ?? null,
        'closed_at' => $root['closed_at'] ?? null,
        'archived_at' => $root['archived_at'] ?? null,
        'keys' => array_slice(array_keys($root), 0, 12),
    ];
}
