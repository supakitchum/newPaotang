<?php

return [
    'enabled_by_default' => (bool) env('CUSTOMER_SUPPORT_ENABLED_BY_DEFAULT', false),
    'api_url' => env('SUPPORT_API_URL', '/support-api/v1'),
    'realtime_url' => env('SUPPORT_REALTIME_URL', 'ws://localhost:8081'),
    'realtime_key' => env('SUPPORT_REALTIME_KEY', 'newpaotang-support'),
    'jwt' => [
        'issuer' => env('SUPPORT_JWT_ISSUER', 'newpaotang-platform-api'),
        'audience' => env('SUPPORT_JWT_AUDIENCE', 'newpaotang-support'),
        'ttl_seconds' => (int) env('SUPPORT_JWT_TTL_SECONDS', 600),
        'private_key_path' => env('SUPPORT_JWT_PRIVATE_KEY_PATH'),
        'private_key' => env('SUPPORT_JWT_PRIVATE_KEY'),
    ],
    'ingress_secret' => env('PLATFORM_SUPPORT_INGRESS_SECRET'),
];
