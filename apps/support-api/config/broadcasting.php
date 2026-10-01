<?php

return [
    'default' => env('BROADCAST_CONNECTION', 'reverb'),
    'connections' => [
        'reverb' => [
            'driver' => 'reverb',
            'key' => env('REVERB_APP_KEY', 'newpaotang-support'),
            'secret' => env('REVERB_APP_SECRET', env('APP_KEY') ?: 'newpaotang-support-secret'),
            'app_id' => env('REVERB_APP_ID', 'newpaotang-support-local'),
            'options' => [
                'host' => env('REVERB_HOST', 'support-reverb'),
                'port' => env('REVERB_PORT', 8081),
                'scheme' => env('REVERB_SCHEME', 'http'),
                'useTLS' => env('REVERB_SCHEME', 'http') === 'https',
            ],
            'client_options' => [],
        ],
        'log' => ['driver' => 'log'],
        'null' => ['driver' => 'null'],
    ],
];
