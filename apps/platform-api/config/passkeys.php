<?php

$csv = static function (mixed $value): array {
    return array_values(array_filter(array_map(
        static fn (string $item): string => trim($item),
        explode(',', (string) $value),
    )));
};

return [
    'relying_party_id' => parse_url((string) config('app.url'), PHP_URL_HOST),
    'allowed_origins' => array_values(array_filter([(string) config('app.url')])),
    'user_handle_secret' => env('PASSKEYS_USER_HANDLE_SECRET', config('app.key')),
    'timeout' => max(1, (int) env('CUSTOMER_PASSKEY_TIMEOUT_MS', 60000)),
    'middleware' => ['web'],
    'management_middleware' => ['password.confirm'],
    'throttle' => 'throttle:6,1',
    'redirect' => '/',

    'customer' => [
        'enabled_default' => filter_var(
            env('CUSTOMER_PASSKEY_ENABLED', true),
            FILTER_VALIDATE_BOOL,
        ),
        'challenge_ttl_seconds' => max(
            60,
            (int) env('CUSTOMER_PASSKEY_CHALLENGE_TTL_SECONDS', 300),
        ),
        'max_per_customer' => max(
            1,
            (int) env('CUSTOMER_PASSKEY_MAX_PER_CUSTOMER', 10),
        ),
        'additional_allowed_origins' => $csv(
            env('CUSTOMER_PASSKEY_ADDITIONAL_ALLOWED_ORIGINS', ''),
        ),
        'ios_app_ids' => $csv(env('CUSTOMER_PASSKEY_IOS_APP_IDS', '')),
        'android' => [
            'package_name' => trim((string) env('CUSTOMER_PASSKEY_ANDROID_PACKAGE_NAME', '')),
            'sha256_cert_fingerprints' => $csv(
                env('CUSTOMER_PASSKEY_ANDROID_SHA256_FINGERPRINTS', ''),
            ),
        ],
    ],
];
