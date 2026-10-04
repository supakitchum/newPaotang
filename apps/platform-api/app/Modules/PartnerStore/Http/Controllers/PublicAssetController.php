<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Models\PlatformAsset;
use App\Modules\PartnerStore\Services\PublicAssetThumbnailService;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Routing\Controller;

class PublicAssetController extends Controller
{
    private const ALLOWED_PREFIXES = [
        'lotteries/',
        'lottery-image-assets/',
        'partners/',
        'central/assets/',
        'tenants/',
    ];

    public function __construct(
        private readonly RuntimeStorageService $storage,
        private readonly PublicAssetThumbnailService $thumbnails,
    ) {
    }

    public function show(Request $request, string $path): Response
    {
        $path = ltrim(rawurldecode($path), '/');

        if ($path === '' || str_contains($path, '..') || str_contains($path, '\\') || ! $this->hasAllowedPrefix($path)) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        $routeKey = $this->storage->routeForStorageKey($path);
        $storageDriver = $this->storageDriver($request->query('storage_driver'));

        if ($request->query('variant') === 'thumb') {
            $asset = PlatformAsset::query()
                ->where('storage_key', $path)
                ->whereIn('purpose', ['tenant_activity_image', 'tenant_announcement_image'])
                ->where('status', 'committed')
                ->first();
            if ($asset !== null) {
                $version = (string) $request->query('v', '');
                if ($version !== '' && ! hash_equals((string) $asset->checksum_sha256, $version)) {
                    return response('', 404, ['Cache-Control' => 'no-store']);
                }
                $bytes = $this->thumbnails->get($asset, $storageDriver);
                if ($bytes !== null) {
                    return $this->imageResponse($request, $bytes, 'image/webp', $version !== '');
                }
            }
        }

        $bytes = $this->storage->getUsingDriver($routeKey, $path, $storageDriver);
        if ($bytes === null) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        $contentType = (new \finfo(FILEINFO_MIME_TYPE))->buffer($bytes)
            ?: (string) config('lottery_images.content_type', 'image/webp');

        return $this->imageResponse($request, $bytes, $contentType);
    }

    private function imageResponse(Request $request, string $bytes, string $contentType, bool $immutable = true): Response
    {
        $response = response($bytes, 200, [
            'Content-Type' => $contentType,
            'Cache-Control' => $immutable
                ? (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable')
                : 'public, max-age=300, must-revalidate',
            'Content-Length' => (string) strlen($bytes),
        ])->setEtag(hash('sha256', $bytes));
        $response->isNotModified($request);

        return $response;
    }

    private function hasAllowedPrefix(string $path): bool
    {
        foreach (array_merge(self::ALLOWED_PREFIXES, $this->storage->publicAllowedPrefixes()) as $prefix) {
            if (str_starts_with($path, $prefix)) {
                return true;
            }
        }

        return false;
    }

    private function storageDriver(mixed $value): ?string
    {
        $driver = trim((string) ($value ?? ''));

        return in_array($driver, [RuntimeStorageService::DRIVER_LOCAL, RuntimeStorageService::DRIVER_AWS_S3], true)
            ? $driver
            : null;
    }
}
