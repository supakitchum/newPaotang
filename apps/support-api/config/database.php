<?php

use Illuminate\Support\Str;

$isTesting = env('APP_ENV') === 'testing';
$database = $isTesting
    ? env('DB_TEST_DATABASE', env('DB_DATABASE_TEST', 'newpaotang_support_test'))
    : env('DB_DATABASE', 'newpaotang_support');

if (! str_contains($database, 'support')) {
    throw new RuntimeException('Support API database must be isolated and include "support" in its name.');
}
if ($isTesting && ! str_ends_with($database, '_test')) {
    throw new RuntimeException('Support API tests must use a database ending with "_test".');
}

return [
    'default' => env('DB_CONNECTION', 'pgsql'),
    'connections' => [
        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', 'support-postgres'),
            'port' => env('DB_PORT', '5432'),
            'database' => $database,
            'username' => env('DB_USERNAME', 'newpaotang_support'),
            'password' => env('DB_PASSWORD', 'newpaotang_support'),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => env('DB_SSLMODE', 'prefer'),
            'timezone' => env('DB_TIMEZONE', 'Asia/Bangkok'),
        ],
    ],
    'migrations' => [
        'table' => 'migrations',
        'update_date_on_publish' => true,
    ],
    'redis' => [
        'client' => env('REDIS_CLIENT', 'predis'),
        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'newpaotang-support'), '_').'_'),
        ],
        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', 'support-valkey'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
        ],
        'cache' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', 'support-valkey'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_CACHE_DB', '1'),
        ],
    ],
];
