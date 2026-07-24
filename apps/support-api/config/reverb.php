<?php

$allowedOrigins = array_values(array_unique(array_filter(array_map(
    static function (string $origin): string {
        $origin = trim($origin);
        if ($origin === '' || $origin === '*' || ! str_contains($origin, '://')) {
            return $origin;
        }

        return (string) (parse_url($origin, PHP_URL_HOST) ?: '');
    },
    explode(',', (string) env('SUPPORT_REVERB_ALLOWED_ORIGINS', '')),
))));

return [
    'default' => 'reverb',
    'servers' => [
        'reverb' => [
            'host' => env('REVERB_SERVER_HOST', '0.0.0.0'),
            'port' => env('REVERB_SERVER_PORT', 8081),
            'path' => env('REVERB_SERVER_PATH', ''),
            'hostname' => env('REVERB_HOST'),
            'options' => ['tls' => []],
            'max_request_size' => env('REVERB_MAX_REQUEST_SIZE', 10_000),
            'scaling' => [
                'enabled' => env('REVERB_SCALING_ENABLED', false),
                'channel' => 'support-reverb',
                'server' => [
                    'url' => env('REDIS_URL'),
                    'host' => env('REDIS_HOST', 'support-valkey'),
                    'port' => env('REDIS_PORT', '6379'),
                    'database' => env('REDIS_DB', '0'),
                    'timeout' => 60,
                ],
            ],
            'pulse_ingest_interval' => 15,
            'telescope_ingest_interval' => 15,
        ],
    ],
    'apps' => [
        'provider' => 'config',
        'apps' => [[
            'key' => env('REVERB_APP_KEY', 'newpaotang-support'),
            'secret' => env('REVERB_APP_SECRET', env('APP_KEY') ?: 'newpaotang-support-secret'),
            'app_id' => env('REVERB_APP_ID', 'newpaotang-support-local'),
            'options' => [
                'host' => env('REVERB_HOST', 'localhost'),
                'port' => env('REVERB_PORT', 8081),
                'scheme' => env('REVERB_SCHEME', 'http'),
                'useTLS' => env('REVERB_SCHEME', 'http') === 'https',
            ],
            'allowed_origins' => $allowedOrigins,
            'ping_interval' => 60,
            'activity_timeout' => 30,
            'max_connections' => env('REVERB_APP_MAX_CONNECTIONS'),
            'max_message_size' => 10_000,
        ]],
    ],
];
