<?php

return [
    'deepay_kbank' => [
        'endpoint' => env('DEEPAY_KBANK_ENDPOINT', 'https://ks-intershop.com/api/v1/payments/kbank'),
        'timeout' => (int) env('DEEPAY_KBANK_TIMEOUT', 15),
    ],
];
