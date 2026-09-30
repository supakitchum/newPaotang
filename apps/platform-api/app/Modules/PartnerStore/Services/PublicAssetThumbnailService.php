<?php

namespace App\Modules\PartnerStore\Services;

use App\Models\PlatformAsset;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Uri;

class PublicAssetThumbnailService
{
    public function __construct(private readonly RuntimeStorageService $storage)
    {
    }

    public static function url(PlatformAsset $asset, string $url): string
    {
        if (! str_contains((string) parse_url($url, PHP_URL_PATH), '/api/v1/public/assets/')
            || ! self::hasVersion($asset)) {
            return $url;
        }

        return (string) Uri::of($url)->withQuery([
            'variant' => 'thumb',
            'v' => $asset->checksum_sha256,
        ]);
    }

    public function get(PlatformAsset $asset, ?string $driver = null): ?string
    {
        if (! self::hasVersion($asset) || ! function_exists('imagewebp')) {
            return null;
        }

        $path = (string) $asset->storage_key;
        $key = 'public-activity-thumb:v1:'.hash('sha256', $path.'|'.$driver.'|'.$asset->checksum_sha256);
        try {
            $cached = Cache::get($key);
            if (is_string($cached)) {
                return $cached;
            }
        } catch (\Throwable) {
            // Image delivery still works when the cache is unavailable.
        }

        $source = $this->storage->getUsingDriver($this->storage->routeForStorageKey($path), $path, $driver);
        if ($source === null || strlen($source) > 8 * 1024 * 1024) {
            return null;
        }

        $size = @getimagesizefromstring($source);
        if ($size === false || $size[0] * $size[1] > 25000000) {
            return null;
        }
        $image = @imagecreatefromstring($source);
        if ($image === false) {
            return null;
        }

        $width = min(480, $size[0]);
        $height = max(1, (int) round($size[1] * $width / $size[0]));
        $canvas = imagecreatetruecolor($width, $height);
        try {
            imagealphablending($canvas, false);
            imagesavealpha($canvas, true);
            imagecopyresampled($canvas, $image, 0, 0, 0, 0, $width, $height, $size[0], $size[1]);
            ob_start();
            try {
                $converted = imagewebp($canvas, null, 76);
                $bytes = ob_get_contents();
            } finally {
                ob_end_clean();
            }
        } finally {
            imagedestroy($canvas);
            imagedestroy($image);
        }

        if (! $converted || ! is_string($bytes) || $bytes === '') {
            return null;
        }
        try {
            Cache::put($key, $bytes, now()->addDay());
        } catch (\Throwable) {
        }

        return $bytes;
    }

    private static function hasVersion(PlatformAsset $asset): bool
    {
        return preg_match('/^[a-f0-9]{64}$/i', (string) $asset->checksum_sha256) === 1;
    }
}
