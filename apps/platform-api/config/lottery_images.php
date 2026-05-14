<?php

return [
    'enabled' => env('LOTTERY_IMAGE_ENABLED', true),
    'disk' => env('LOTTERY_IMAGE_DISK', 'lottery_images'),
    'cdn_base_url' => env('LOTTERY_IMAGE_CDN_BASE_URL', env('CDN_BASE_URL', 'https://local-assets.newpaotang.test')),
    'object_prefix' => env('LOTTERY_IMAGE_OBJECT_PREFIX', 'lotteries'),
    'asset_root' => env('LOTTERY_IMAGE_ASSET_ROOT', resource_path('lottery-images')),
    'background_version' => env('LOTTERY_IMAGE_BACKGROUND_VERSION', 'v1'),
    'background_min_counts' => [
        'odd' => (int) env('LOTTERY_IMAGE_ODD_BACKGROUND_MIN_COUNT', 1),
        'even' => (int) env('LOTTERY_IMAGE_EVEN_BACKGROUND_MIN_COUNT', 1),
        'charity' => (int) env('LOTTERY_IMAGE_CHARITY_BACKGROUND_MIN_COUNT', 1),
    ],
    'background_mix' => [
        'odd' => 45,
        'even' => 45,
        'charity' => 10,
    ],
    'dimensions' => [
        'full' => ['width' => 500, 'quality' => 70],
        'thumb' => ['width' => 280, 'quality' => 60],
    ],
    'queues' => [
        'central' => env('LOTTERY_IMAGE_CENTRAL_QUEUE', 'stock-image-generation'),
        'partner' => env('LOTTERY_IMAGE_PARTNER_QUEUE', 'stock-partner-image-generation'),
    ],
    'content_type' => 'image/webp',
    'cache_control' => env('LOTTERY_IMAGE_CACHE_CONTROL', 'public, max-age=31536000, immutable'),
];
