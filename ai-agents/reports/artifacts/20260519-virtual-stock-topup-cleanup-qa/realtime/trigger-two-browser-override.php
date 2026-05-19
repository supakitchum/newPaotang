<?php

use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

require 'vendor/autoload.php';

$app = require 'bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$now = now();

AdminUser::updateOrCreate(
    ['email' => 'qa-realtime-trigger@newpaotang.test'],
    [
        'id' => 'adm_qa_realtime_trigger',
        'name' => 'QA Realtime Trigger',
        'phone' => null,
        'password_hash' => Hash::make((string) config('platform.seed.central_admin_password')),
        'status' => 'active',
        'two_factor_enabled' => false,
    ],
);

AdminUserRole::query()->insertOrIgnore([[
    'admin_user_id' => 'adm_qa_realtime_trigger',
    'role_id' => 'rol_c_super_admin',
    'scope_id' => 'scp_c_platform',
    'created_at' => $now,
    'updated_at' => $now,
]]);

AdminPermissionCacheVersion::updateOrCreate(
    ['admin_user_id' => 'adm_qa_realtime_trigger', 'scope_id' => 'scp_c_platform'],
    ['id' => 'pcv_qa_realtime_trigger', 'version' => 2],
);

$baseUrl = 'http://host.docker.internal:8002/api/v1';

$login = Http::acceptJson()->post($baseUrl.'/auth/admin/login', [
    'email' => 'qa-realtime-trigger@newpaotang.test',
    'password' => (string) config('platform.seed.central_admin_password'),
    'scope' => 'central',
]);

$accessToken = (string) data_get($login->json(), 'access_token');

$result = [
    'fixture_admin_ready' => true,
    'login_status' => $login->status(),
    'login_has_access_token' => $accessToken !== '',
];

if ($accessToken !== '') {
    $response = Http::acceptJson()
        ->withToken($accessToken)
        ->withHeaders([
            'X-Admin-Scope' => 'central',
            'Idempotency-Key' => 'qa-two-browser-override-'.str_replace('.', '-', (string) microtime(true)),
            'X-Request-Id' => 'qa-two-browser-realtime',
        ])
        ->put($baseUrl.'/admin/central/stock/limit-overrides', [
            'game_id' => 'gam_qa_topup',
            'scope_type' => 'central',
            'scope_id' => 'central',
            'dimension' => 'back2',
            'overrides' => [
                ['value' => '56', 'limit' => 1],
            ],
        ]);

    $rows = data_get($response->json(), 'data.data', data_get($response->json(), 'data', []));
    $row = collect(is_array($rows) ? $rows : [])
        ->first(fn (array $item): bool => ($item['number'] ?? null) === '56');

    $result += [
        'override_status' => $response->status(),
        'override_row' => [
            'number' => $row['number'] ?? null,
            'generated_count' => $row['generated_count'] ?? null,
            'reserved_count' => $row['reserved_count'] ?? null,
            'sold_count' => $row['sold_count'] ?? null,
            'default_limit' => $row['default_limit'] ?? null,
            'override_limit' => $row['override_limit'] ?? null,
            'limit' => $row['limit'] ?? null,
            'remaining_limit' => $row['remaining_limit'] ?? null,
            'sellable_remaining_count' => $row['sellable_remaining_count'] ?? null,
        ],
    ];
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
