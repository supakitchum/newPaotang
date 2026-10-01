<?php

return [
    'enabled' => env('LOTTERY_IMAGE_ENABLED', true),
    'disk' => env('LOTTERY_IMAGE_DISK', 'lottery_images'),
    'cdn_base_url' => env('LOTTERY_IMAGE_CDN_BASE_URL', env('CDN_BASE_URL', 'https://local-assets.newpaotang.test')),
    'local_public_base_url' => env('LOTTERY_IMAGE_LOCAL_PUBLIC_BASE_URL', rtrim(env('APP_URL', 'http://localhost:8000'), '/').'/api/v1/public/assets'),
    'object_prefix' => env('LOTTERY_IMAGE_OBJECT_PREFIX', 'lotteries'),
    'asset_root' => env('LOTTERY_IMAGE_ASSET_ROOT', resource_path('lottery-images')),
    'runtime' => env('LOTTERY_IMAGE_RUNTIME', 'gd'),
    'preview_cache_ttl_seconds' => (int) env('LOTTERY_IMAGE_PREVIEW_CACHE_TTL_SECONDS', 600),
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
    'background_asset_limits' => [
        'max_source_size_bytes' => (int) env('LOTTERY_IMAGE_BACKGROUND_SOURCE_MAX_BYTES', 10485760),
        'max_full_size_bytes' => (int) env('LOTTERY_IMAGE_BACKGROUND_FULL_MAX_BYTES', 5242880),
        'max_thumb_size_bytes' => (int) env('LOTTERY_IMAGE_BACKGROUND_THUMB_MAX_BYTES', 1048576),
        'allowed_source_mimes' => ['image/webp', 'image/png', 'image/jpeg'],
        'required_variant_mime' => 'image/webp',
    ],
    'background_zip_import' => [
        'max_entries' => (int) env('LOTTERY_IMAGE_BACKGROUND_ZIP_MAX_ENTRIES', 150),
        'max_uncompressed_bytes' => (int) env('LOTTERY_IMAGE_BACKGROUND_ZIP_MAX_UNCOMPRESSED_BYTES', 67108864),
        'max_compression_ratio' => (float) env('LOTTERY_IMAGE_BACKGROUND_ZIP_MAX_COMPRESSION_RATIO', 80),
    ],
    'dimensions' => [
        'full' => [
            'width' => (int) env('LOTTERY_IMAGE_FULL_WIDTH', 500),
            'height' => (int) env('LOTTERY_IMAGE_FULL_HEIGHT', 280),
            'quality' => (int) env('LOTTERY_IMAGE_FULL_QUALITY', 70),
        ],
        'thumb' => [
            'width' => (int) env('LOTTERY_IMAGE_THUMB_WIDTH', 280),
            'height' => (int) env('LOTTERY_IMAGE_THUMB_HEIGHT', 157),
            'quality' => (int) env('LOTTERY_IMAGE_THUMB_QUALITY', 60),
        ],
    ],
    'queues' => [
        'central' => env('LOTTERY_IMAGE_CENTRAL_QUEUE', 'stock-image-generation'),
        'partner' => env('LOTTERY_IMAGE_PARTNER_QUEUE', 'stock-partner-image-generation'),
        'sold' => env('LOTTERY_IMAGE_SOLD_QUEUE', env('LOTTERY_IMAGE_PARTNER_QUEUE', 'stock-partner-image-generation')),
    ],
    'content_type' => 'image/webp',
    'cache_control' => env('LOTTERY_IMAGE_CACHE_CONTROL', 'public, max-age=31536000, immutable'),
];
