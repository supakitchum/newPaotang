<?php

$baseUrl = 'http://127.0.0.1:8010/api/v1/public/stock/search';
$query = [
    'game_id' => 'gam_qa_exact6',
    'number' => '654321',
    'limit' => 2,
];

$fetch = function (array $params) use ($baseUrl): array {
    $url = $baseUrl.'?'.http_build_query($params);
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "Host: localhost\r\nAccept: application/json\r\nX-Request-Id: req_qa_exact_six\r\n",
            'ignore_errors' => true,
        ],
    ]);
    $body = file_get_contents($url, false, $context);

    if ($body === false) {
        throw new RuntimeException('HTTP request failed: '.$url);
    }

    $decoded = json_decode($body, true, flags: JSON_THROW_ON_ERROR);

    return [
        'url' => $url,
        'status_line' => $http_response_header[0] ?? 'unknown',
        'body' => $decoded,
    ];
};

$pageOne = $fetch($query);
$cursor = $pageOne['body']['meta']['next_cursor'] ?? null;
$pageTwo = $fetch($query + ['cursor' => $cursor]);
$rows = array_merge($pageOne['body']['data'] ?? [], $pageTwo['body']['data'] ?? []);
$ids = array_values(array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $rows));

echo json_encode([
    'api_base_url' => 'http://127.0.0.1:8010/api/v1',
    'host_header' => 'localhost',
    'game_id' => 'gam_qa_exact6',
    'number' => '654321',
    'limit' => 2,
    'page_one' => [
        'status_line' => $pageOne['status_line'],
        'count' => count($pageOne['body']['data'] ?? []),
        'full_numbers' => array_values(array_map(fn (array $row): string => (string) ($row['full_number'] ?? ''), $pageOne['body']['data'] ?? [])),
        'ids' => array_values(array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $pageOne['body']['data'] ?? [])),
        'virtual_copy_indexes' => array_values(array_map(fn (array $row): int => (int) ($row['virtual_copy_index'] ?? -1), $pageOne['body']['data'] ?? [])),
        'has_more' => $pageOne['body']['meta']['has_more'] ?? null,
        'next_cursor' => $cursor,
    ],
    'page_two' => [
        'status_line' => $pageTwo['status_line'],
        'count' => count($pageTwo['body']['data'] ?? []),
        'full_numbers' => array_values(array_map(fn (array $row): string => (string) ($row['full_number'] ?? ''), $pageTwo['body']['data'] ?? [])),
        'ids' => array_values(array_map(fn (array $row): string => (string) ($row['id'] ?? ''), $pageTwo['body']['data'] ?? [])),
        'virtual_copy_indexes' => array_values(array_map(fn (array $row): int => (int) ($row['virtual_copy_index'] ?? -1), $pageTwo['body']['data'] ?? [])),
        'has_more' => $pageTwo['body']['meta']['has_more'] ?? null,
        'next_cursor' => $pageTwo['body']['meta']['next_cursor'] ?? null,
    ],
    'combined_ids' => $ids,
    'unique_id_count' => count(array_unique($ids)),
    'no_repeated_ids_across_pages' => count($ids) === count(array_unique($ids)),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
