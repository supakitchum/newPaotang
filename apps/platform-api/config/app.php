<?php

return [
    'name' => env('APP_NAME', 'NewPaotang Platform API'),
    'env' => env('APP_ENV', 'production'),
    'debug' => (bool) env('APP_DEBUG', false),
    'url' => env('APP_URL', 'http://localhost'),
    'back_office_url' => env('PLATFORM_BACK_OFFICE_URL', env('APP_URL', 'http://localhost')),
    'admin_invitation_ttl_hours' => (int) env('ADMIN_INVITATION_TTL_HOURS', 168),
    'timezone' => env('APP_TIMEZONE', 'Asia/Bangkok'),
    'locale' => 'en',
    'fallback_locale' => 'en',
    'faker_locale' => 'en_US',
    'key' => env('APP_KEY'),
    'cipher' => 'AES-256-CBC',
    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE', 'database'),
    ],
];
