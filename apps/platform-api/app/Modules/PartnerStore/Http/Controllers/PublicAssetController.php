<?php

namespace App\Modules\PartnerStore\Http\Controllers;

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

    public function __construct(private readonly RuntimeStorageService $storage)
    {
    }

    public function show(Request $request, string $path): Response
    {
        $path = ltrim(rawurldecode($path), '/');

        if ($path === '' || str_contains($path, '..') || str_contains($path, '\\') || ! $this->hasAllowedPrefix($path)) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        $routeKey = $this->storage->routeForStorageKey($path);
        $storageDriver = $this->storageDriver($request->query('storage_driver'));

        if (! $this->storage->existsUsingDriver($routeKey, $path, $storageDriver)) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        $bytes = $this->storage->getUsingDriver($routeKey, $path, $storageDriver);
        if ($bytes === null) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        return response($bytes, 200, [
            'Content-Type' => $this->storage->mimeTypeUsingDriver($routeKey, $path, $storageDriver) ?: (string) config('lottery_images.content_type', 'image/webp'),
            'Cache-Control' => (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable'),
        ]);
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
