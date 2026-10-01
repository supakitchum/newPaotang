<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$baseUrl = rtrim(getenv('QA_API_BASE') ?: 'http://platform-api:8000/api/v1', '/');
$run = strtolower(bin2hex(random_bytes(4)));
$unlockedPartnerId = 'par_lba_un_'.$run;
$unlockedTenantId = 'ten_lba_un_'.$run;
$lockedPartnerId = 'par_lba_lo_'.$run;
$lockedTenantId = 'ten_lba_lo_'.$run;
$events = [];

$centralToken = null;
$tenantToken = null;

$record = function (string $label, string $method, string $path, int $status, array $headers, array $payload = [], mixed $json = null) use (&$events): void {
    $events[] = [
        'label' => $label,
        'method' => strtoupper($method),
        'path' => $path,
        'status' => $status,
        'payload_keys' => payloadKeys($payload),
        'headers' => [
            'x_admin_scope' => $headers['X-Admin-Scope'] ?? null,
            'x_tenant_id' => $headers['X-Tenant-Id'] ?? null,
            'x_request_id_present' => isset($headers['X-Request-Id']),
            'idempotency_key_present' => isset($headers['Idempotency-Key']),
            'authorization_present' => isset($headers['Authorization']),
        ],
        'resource' => summarizeResource($json),
        'error_code' => is_array($json) ? ($json['error']['code'] ?? null) : null,
    ];
};

$insertPartnerTenant = function (string $partnerId, string $tenantId): void {
    DB::table('partners')->insert([
        'id' => $partnerId,
        'code' => $partnerId,
        'name' => 'QA Lottery Branding '.$partnerId,
        'type' => 'partner_store',
        'status' => 'active',
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    DB::table('partner_tenants')->insert([
        'id' => $tenantId,
        'partner_id' => $partnerId,
        'code' => $tenantId,
        'name' => 'QA Lottery Branding '.$tenantId,
        'status' => 'active',
        'created_at' => now(),
        'updated_at' => now(),
    ]);
};

$insertLockedGeneratedImage = function (string $partnerId, string $tenantId) use ($run): void {
    $gameId = 'gam_lba_'.$run;
    $stockId = 'stk_lba_'.$run;

    DB::table('games')->insert([
        'id' => $gameId,
        'code' => $gameId,
        'name' => 'QA Lottery Branding '.$run,
        'sale_start_at' => now()->subHour(),
        'draw_at' => now()->addDays(7),
        'close_at' => now()->addDays(6),
        'closed_at' => null,
        'archived_at' => null,
        'status' => 'open',
        'metadata_json' => json_encode(['source' => 'qa-lottery-branding'], JSON_THROW_ON_ERROR),
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    DB::table('stock_items')->insert([
        'id' => $stockId,
        'game_id' => $gameId,
        'batch_id' => null,
        'full_number' => '420001',
        'front3' => '420',
        'back3' => '001',
        'back2' => '01',
        'status' => 'allocated',
        'partner_id' => $partnerId,
        'tenant_id' => $tenantId,
        'allocation_id' => null,
        'recall_reason' => null,
        'recalled_at' => null,
        'image_url' => null,
        'image_thumb_url' => null,
        'image_storage_path' => null,
        'image_thumb_storage_path' => null,
        'image_generation_status' => 'generated',
        'image_generation_error' => null,
        'image_generated_at' => now(),
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    DB::table('local_stock_items')->insert([
        'id' => 'lsi_lba_'.$run,
        'tenant_id' => $tenantId,
        'partner_id' => $partnerId,
        'store_id' => 'qa-lba',
        'game_id' => $gameId,
        'stock_item_id' => $stockId,
        'allocation_id' => null,
        'full_number' => '420001',
        'front3' => '420',
        'back3' => '001',
        'back2' => '01',
        'image_url' => 'https://cdn.example.test/lotteries/'.$gameId.'/partners/'.$partnerId.'/lsi_lba_'.$run.'.webp',
        'image_thumb_url' => 'https://cdn.example.test/lotteries/'.$gameId.'/partners/'.$partnerId.'/thumbs/lsi_lba_'.$run.'.webp',
        'image_storage_path' => 'lotteries/'.$gameId.'/partners/'.$partnerId.'/lsi_lba_'.$run.'.webp',
        'image_thumb_storage_path' => 'lotteries/'.$gameId.'/partners/'.$partnerId.'/thumbs/lsi_lba_'.$run.'.webp',
        'image_generation_status' => 'generated',
        'image_generation_error' => null,
        'image_generated_at' => now(),
        'status' => 'available',
        'synced_at' => now(),
        'reserved_at' => null,
        'sold_at' => null,
        'created_at' => now(),
        'updated_at' => now(),
    ]);
};

$login = function (string $scope) use ($baseUrl, $record): string {
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
            'tenant_id' => 'ten_demo_alpha',
        ];

    $response = Http::acceptJson()->timeout(20)->post($baseUrl.'/auth/admin/login', $payload);
    $json = $response->json();
    $record($scope.'-login', 'POST', '/auth/admin/login', $response->status(), [], [
        'email' => $payload['email'],
        'scope' => $payload['scope'],
        'tenant_id' => $payload['tenant_id'] ?? null,
    ], [
        'active_scope' => $json['active_scope'] ?? null,
        'access_token_present' => isset($json['access_token']),
        'refresh_token_present' => isset($json['refresh_token']),
    ]);

    if ($response->failed() || ! is_array($json) || ! isset($json['access_token'])) {
        throw new RuntimeException($scope.' login failed with HTTP '.$response->status());
    }

    return (string) $json['access_token'];
};

$request = function (string $scope, string $label, string $method, string $path, array $payload = [], bool $write = false, bool $allowFailure = false) use ($baseUrl, &$centralToken, &$tenantToken, $record): array {
    $headers = [
        'Accept' => 'application/json',
        'X-Admin-Scope' => $scope,
        'X-Request-Id' => 'qa-lba-'.$label,
        'Authorization' => 'Bearer '.($scope === 'central' ? $centralToken : $tenantToken),
    ];

    if ($scope === 'tenant') {
        $headers['X-Tenant-Id'] = 'ten_demo_alpha';
    }

    if ($write) {
        $headers['Idempotency-Key'] = 'qa-lba-'.$label.'-'.bin2hex(random_bytes(4));
    }

    $pending = Http::withHeaders($headers)->timeout(20);
    $response = match (strtoupper($method)) {
        'GET' => $pending->get($baseUrl.$path),
        'POST' => $pending->post($baseUrl.$path, $payload),
        'PUT' => $pending->put($baseUrl.$path, $payload),
        default => throw new InvalidArgumentException('Unsupported method '.$method),
    };
    $json = $response->body() === '' ? null : $response->json();
    $record($label, $method, $path, $response->status(), $headers, $payload, $json);

    if ($response->failed() && ! $allowFailure) {
        throw new RuntimeException($label.' failed with HTTP '.$response->status().': '.substr($response->body(), 0, 500));
    }

    return is_array($json) ? $json : [];
};

$uploadAndCommit = function (string $slot, string $contentType = 'image/webp', int $size = 1024) use ($request, $unlockedPartnerId): string {
    $checksum = hash('sha256', 'qa-lba-'.$slot);
    $intent = $request('central', 'upload-'.$slot, 'POST', '/admin/central/assets/uploads', [
        'purpose' => 'ticket_image',
        'file_name' => $slot.'.webp',
        'content_type' => $contentType,
        'size_bytes' => $size,
        'checksum_sha256' => $checksum,
        'metadata' => [
            'partner_id' => $unlockedPartnerId,
            'branding_slot' => $slot,
            'version' => 'v1',
        ],
    ], true);

    $assetId = (string) ($intent['asset_id'] ?? '');
    if ($assetId === '') {
        throw new RuntimeException('Upload intent did not return asset_id for '.$slot);
    }

    $request('central', 'commit-'.$slot, 'POST', '/admin/central/assets/'.$assetId.'/commit', [
        'checksum_sha256' => $checksum,
        'metadata' => [
            'partner_id' => $unlockedPartnerId,
            'branding_slot' => $slot,
            'version' => 'v1',
            'file_name' => $slot.'.webp',
        ],
    ], true);

    return $assetId;
};

$insertPartnerTenant($unlockedPartnerId, $unlockedTenantId);
$insertPartnerTenant($lockedPartnerId, $lockedTenantId);
$insertLockedGeneratedImage($lockedPartnerId, $lockedTenantId);

$centralToken = $login('central');
$tenantToken = $login('tenant');

$unlockedReadBefore = $request('central', 'unlocked-read-before', 'GET', '/admin/central/partners/'.$unlockedPartnerId.'/lottery-branding-assets');

$tenantRejected = $request('tenant', 'tenant-central-put-rejected', 'PUT', '/admin/central/partners/'.$unlockedPartnerId.'/lottery-branding-assets', [
    'version' => 'v1',
    'assets' => [
        'logo_qr' => ['asset_id' => 'ast_does_not_matter'],
        'right_sidebar' => ['asset_id' => 'ast_does_not_matter'],
        'logo_bottom' => ['asset_id' => 'ast_does_not_matter'],
    ],
], true, true);

$assetIds = [
    'logo_qr' => $uploadAndCommit('logo_qr'),
    'right_sidebar' => $uploadAndCommit('right_sidebar'),
    'logo_bottom' => $uploadAndCommit('logo_bottom'),
];

$saved = $request('central', 'unlocked-save', 'PUT', '/admin/central/partners/'.$unlockedPartnerId.'/lottery-branding-assets', [
    'version' => 'v1',
    'assets' => [
        'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
        'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
        'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
    ],
], true);

$unlockedReadAfter = $request('central', 'unlocked-read-after', 'GET', '/admin/central/partners/'.$unlockedPartnerId.'/lottery-branding-assets');
$lockedRead = $request('central', 'locked-read', 'GET', '/admin/central/partners/'.$lockedPartnerId.'/lottery-branding-assets');
$lockedConflict = $request('central', 'locked-forced-save', 'PUT', '/admin/central/partners/'.$lockedPartnerId.'/lottery-branding-assets', [
    'version' => 'v1',
    'assets' => [
        'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
        'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
        'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
    ],
], true, true);

$saveEvent = collect($events)->firstWhere('label', 'unlocked-save');

$result = [
    'result' => 'PASS',
    'run' => $run,
    'base_url' => $baseUrl,
    'fixtures' => [
        'unlocked_partner_id' => $unlockedPartnerId,
        'locked_partner_id' => $lockedPartnerId,
        'asset_ids' => $assetIds,
    ],
    'checks' => [
        'unlocked_initial_missing_and_editable' => ($unlockedReadBefore['status'] ?? null) === 'missing'
            && ($unlockedReadBefore['locked'] ?? null) === false
            && ($unlockedReadBefore['generated_image_count'] ?? null) === 0,
        'tenant_scope_rejected' => ($tenantRejected['error']['code'] ?? null) === 'permission_denied',
        'save_payload_nested_asset_ids' => ($saveEvent['payload_keys'] ?? []) === [
                'version',
                'assets',
                'assets.logo_qr',
                'assets.logo_qr.asset_id',
                'assets.right_sidebar',
                'assets.right_sidebar.asset_id',
                'assets.logo_bottom',
                'assets.logo_bottom.asset_id',
            ],
        'unlocked_save_ready' => ($saved['status'] ?? null) === 'ready'
            && ($saved['locked'] ?? null) === false
            && ($saved['assets']['logo_qr']['asset_id'] ?? null) === $assetIds['logo_qr']
            && ($saved['assets']['right_sidebar']['asset_id'] ?? null) === $assetIds['right_sidebar']
            && ($saved['assets']['logo_bottom']['asset_id'] ?? null) === $assetIds['logo_bottom'],
        'post_save_metadata_present' => collect(['logo_qr', 'right_sidebar', 'logo_bottom'])
            ->every(fn (string $slot): bool => isset($unlockedReadAfter['assets'][$slot]['asset_id'], $unlockedReadAfter['assets'][$slot]['file_name'], $unlockedReadAfter['assets'][$slot]['storage_path'])),
        'local_dev_metadata_only_not_production_ready' => collect($events)
            ->filter(fn (array $event): bool => str_starts_with((string) $event['label'], 'upload-') || str_starts_with((string) $event['label'], 'commit-'))
            ->every(fn (array $event): bool => ($event['resource']['storage_mode'] ?? null) === 'local_dev_metadata_only' && ($event['resource']['production_storage_ready'] ?? null) === false),
        'locked_state_reported' => ($lockedRead['locked'] ?? null) === true
            && ($lockedRead['status'] ?? null) === 'locked'
            && ($lockedRead['lock_reason'] ?? null) === 'partner_images_already_generated'
            && (int) ($lockedRead['generated_image_count'] ?? 0) > 0,
        'locked_forced_save_conflicts' => ($lockedConflict['error']['code'] ?? null) === 'resource_conflict',
        'central_writes_have_scope_and_idempotency' => collect($events)
            ->filter(fn (array $event): bool => in_array($event['method'], ['POST', 'PUT'], true) && ! str_contains((string) $event['path'], '/auth/admin/login') && $event['headers']['x_admin_scope'] === 'central')
            ->every(fn (array $event): bool => $event['headers']['idempotency_key_present'] === true),
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

    if (isset($json['error'])) {
        return [];
    }

    return [
        'partner_id' => $json['partner_id'] ?? null,
        'asset_set_id' => $json['asset_set_id'] ?? null,
        'version' => $json['version'] ?? null,
        'status' => $json['status'] ?? null,
        'locked' => $json['locked'] ?? null,
        'lock_reason' => $json['lock_reason'] ?? null,
        'generated_image_count' => $json['generated_image_count'] ?? null,
        'asset_id' => $json['asset_id'] ?? $json['id'] ?? null,
        'file_name' => $json['file_name'] ?? null,
        'storage_mode' => $json['storage_mode'] ?? null,
        'production_storage_ready' => $json['production_storage_ready'] ?? null,
        'asset_slots' => isset($json['assets']) && is_array($json['assets']) ? array_keys($json['assets']) : null,
    ];
}
