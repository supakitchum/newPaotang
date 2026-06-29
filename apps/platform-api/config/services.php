<?php

return [
    'deepay_kbank' => [
        'endpoint' => env('DEEPAY_KBANK_ENDPOINT', 'https://ks-intershop.com/api/v1/payments/kbank'),
        'timeout' => (int) env('DEEPAY_KBANK_TIMEOUT', 15),
    ],
    'thaibulksms' => [
        'otp_request_endpoint' => env('THAIBULKSMS_OTP_REQUEST_ENDPOINT', 'https://otp.thaibulksms.com/v2/otp/request'),
        'otp_verify_endpoint' => env('THAIBULKSMS_OTP_VERIFY_ENDPOINT', 'https://otp.thaibulksms.com/v2/otp/verify'),
        'timeout' => (int) env('THAIBULKSMS_OTP_TIMEOUT', 15),
    ],
];
