<?php

return [
    'rate_limits' => [
        'public_referral_clicks_per_minute' => max(
            1,
            (int) env('AFFILIATE_PUBLIC_REFERRAL_CLICKS_PER_MINUTE', 60),
        ),
        'customer_writes_per_minute' => max(
            1,
            (int) env('AFFILIATE_CUSTOMER_WRITES_PER_MINUTE', 20),
        ),
    ],
];
