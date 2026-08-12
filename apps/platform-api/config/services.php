<?php

return [
    'payment_webhooks' => [
        'timestamp_tolerance_seconds' => max(30, (int) env('PAYMENT_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS', 300)),
    ],
    'deepay_kbank' => [
        'endpoint' => env('DEEPAY_KBANK_ENDPOINT', 'https://ks-intershop.com/api/v1/payments/kbank'),
        'timeout' => (int) env('DEEPAY_KBANK_TIMEOUT', 15),
    ],
    'topup' => [
        'qr_ttl_seconds' => max(60, (int) env('TOPUP_QR_TTL_SECONDS', 300)),
    ],
    'thaibulksms' => [
        'otp_request_endpoint' => env('THAIBULKSMS_OTP_REQUEST_ENDPOINT', 'https://otp.thaibulksms.com/v2/otp/request'),
        'otp_verify_endpoint' => env('THAIBULKSMS_OTP_VERIFY_ENDPOINT', 'https://otp.thaibulksms.com/v2/otp/verify'),
        'timeout' => (int) env('THAIBULKSMS_OTP_TIMEOUT', 15),
    ],
    'firebase_cloud_messaging' => [
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'endpoint' => env('FIREBASE_MESSAGING_ENDPOINT', 'https://fcm.googleapis.com/v1'),
        'timeout' => (int) env('FIREBASE_MESSAGING_TIMEOUT', 15),
        'device_stale_days' => (int) env('CUSTOMER_PUSH_DEVICE_STALE_DAYS', 270),
    ],
];
