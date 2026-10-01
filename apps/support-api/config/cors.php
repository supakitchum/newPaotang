<?php

$list = static fn (string $key): array => array_values(array_filter(array_map(
    'trim',
    explode(',', (string) env($key, '')),
)));
$regexList = static fn (string $key): array => array_map(
    static function (string $pattern): string {
        foreach (['/', '~', '#', '%', '!', '@', ';', '`'] as $delimiter) {
            if (
                str_starts_with($pattern, $delimiter)
                && ($closing = strrpos($pattern, $delimiter)) > 0
                && preg_match('/^[imsxuADUJSX]*$/', substr($pattern, $closing + 1)) === 1
            ) {
                return $pattern;
            }
        }

        foreach (['~', '#', '%', '!'] as $delimiter) {
            if (! str_contains($pattern, $delimiter)) {
                return $delimiter.$pattern.$delimiter;
            }
        }

        return '~'.str_replace('~', '\~', $pattern).'~';
    },
    $list($key),
);

return [
    'paths' => ['v1/*', 'attachments/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => $list('SUPPORT_CORS_ALLOWED_ORIGINS'),
    'allowed_origins_patterns' => $regexList('SUPPORT_CORS_ALLOWED_ORIGIN_PATTERNS'),
    'allowed_headers' => [
        'Accept',
        'Accept-Language',
        'Authorization',
        'Content-Type',
        'Idempotency-Key',
        'X-Requested-With',
    ],
    'exposed_headers' => [],
    'max_age' => 600,
    'supports_credentials' => false,
];
