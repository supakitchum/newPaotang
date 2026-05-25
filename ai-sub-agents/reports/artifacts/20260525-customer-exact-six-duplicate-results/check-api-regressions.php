<?php

$apiBase = 'http://127.0.0.1:8010/api/v1';

$fetch = function (string $path, array $params = []) use ($apiBase): array {
    $url = $apiBase.$path.($params === [] ? '' : '?'.http_build_query($params));
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "Host: localhost\r\nAccept: application/json\r\nX-Request-Id: req_qa_exact_six_regression\r\n",
            'ignore_errors' => true,
        ],
    ]);
    $body = file_get_contents($url, false, $context);

    if ($body === false) {
        throw new RuntimeException('HTTP request failed: '.$url);
    }

    return [
        'url' => $url,
        'status_line' => $http_response_header[0] ?? 'unknown',
        'body' => json_decode($body, true, flags: JSON_THROW_ON_ERROR),
    ];
};

$siteConfig = $fetch('/public/site-config');
$currentGame = $fetch('/public/games/current');
$exactAll = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'number' => '654321',
    'limit' => 10,
]);
$storeExact = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'store_id' => 'ten_qa_exact6',
    'number' => '654321',
    'limit' => 10,
]);
$partial = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'd1' => 6,
    'd2' => 5,
    'limit' => 10,
]);
$browse = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'mode' => 'random',
    'limit' => 3,
]);
$empty = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'number' => '000000',
    'limit' => 10,
]);
$apiError = $fetch('/public/stock/search', [
    'game_id' => 'gam_qa_exact6',
    'd3' => 12,
]);

$summarizeSearch = fn (array $response): array => [
    'status_line' => $response['status_line'],
    'count' => count($response['body']['data'] ?? []),
    'full_numbers' => array_values(array_map(fn (array $row): string => (string) ($row['full_number'] ?? ''), $response['body']['data'] ?? [])),
    'ids' => array_values(array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $response['body']['data'] ?? [])),
    'has_more' => $response['body']['meta']['has_more'] ?? null,
    'next_cursor' => $response['body']['meta']['next_cursor'] ?? null,
];

echo json_encode([
    'api_base_url' => $apiBase,
    'host_header' => 'localhost',
    'site_config' => [
        'status_line' => $siteConfig['status_line'],
        'tenant_id' => $siteConfig['body']['data']['tenant_id'] ?? null,
        'api_base_url' => $siteConfig['body']['data']['api']['base_url'] ?? null,
        'maintenance_active' => $siteConfig['body']['data']['maintenance']['active'] ?? null,
    ],
    'current_game' => [
        'status_line' => $currentGame['status_line'],
        'id' => $currentGame['body']['id'] ?? null,
        'status' => $currentGame['body']['status'] ?? null,
    ],
    'exact_all_limit_10' => $summarizeSearch($exactAll),
    'store_filtered_exact' => $summarizeSearch($storeExact),
    'partial_positional_d1_d2' => $summarizeSearch($partial),
    'browse_random' => $summarizeSearch($browse),
    'empty_exact' => $summarizeSearch($empty),
    'api_error_invalid_digit' => [
        'status_line' => $apiError['status_line'],
        'error_code' => $apiError['body']['error']['code'] ?? null,
    ],
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
