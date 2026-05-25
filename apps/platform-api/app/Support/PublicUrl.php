<?php

namespace App\Support;

use Illuminate\Support\Facades\Storage;

final class PublicUrl
{
    public static function asset(string $key): string
    {
        $baseUrl = self::assetBaseUrl();

        if ($baseUrl !== '') {
            return rtrim($baseUrl, '/').'/'.ltrim($key, '/');
        }

        return self::normalizeAssetUrl(Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->url($key));
    }

    public static function normalizeAssetUrl(mixed $url): ?string
    {
        if ($url === null) {
            return null;
        }

        $url = trim((string) $url);

        if ($url === '') {
            return null;
        }

        if (! self::isProduction() && self::isLocalAssetHost($url)) {
            $path = ltrim((string) (parse_url($url, PHP_URL_PATH) ?: ''), '/');

            return $path === '' ? self::absolute($url) : self::asset($path);
        }

        return self::absolute($url);
    }

    public static function absolute(string $url): string
    {
        $url = trim($url);

        if (! self::isProduction() && str_starts_with(strtolower($url), 'https://')) {
            return 'http://'.substr($url, 8);
        }

        return $url;
    }

    private static function assetBaseUrl(): string
    {
        $cdnBaseUrl = trim((string) config('lottery_images.cdn_base_url', ''));
        $localBaseUrl = trim((string) config('lottery_images.local_public_base_url', ''));

        if (! self::isProduction() && ($localBaseUrl !== '' || $cdnBaseUrl === '' || self::isLocalAssetHost($cdnBaseUrl))) {
            return self::absolute($localBaseUrl !== '' ? $localBaseUrl : $cdnBaseUrl);
        }

        return self::absolute($cdnBaseUrl);
    }

    private static function isLocalAssetHost(string $url): bool
    {
        $host = strtolower((string) (parse_url($url, PHP_URL_HOST) ?: ''));

        return $host === 'local-assets.newpaotang.test'
            || $host === 'local-assets.newpaotang.localhost';
    }

    private static function isProduction(): bool
    {
        return (string) config('app.env', app()->environment()) === 'production';
    }
}
