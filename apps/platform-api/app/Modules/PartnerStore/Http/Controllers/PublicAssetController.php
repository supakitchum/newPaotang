<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use Illuminate\Http\Response;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Storage;

class PublicAssetController extends Controller
{
    private const ALLOWED_PREFIXES = [
        'lotteries/',
        'partners/',
        'central/assets/',
        'tenants/',
    ];

    public function show(string $path): Response
    {
        $path = ltrim(rawurldecode($path), '/');

        if ($path === '' || str_contains($path, '..') || str_contains($path, '\\') || ! $this->hasAllowedPrefix($path)) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));

        if (! $disk->exists($path)) {
            return response('', 404, ['Cache-Control' => 'no-store']);
        }

        return response((string) $disk->get($path), 200, [
            'Content-Type' => $disk->mimeType($path) ?: (string) config('lottery_images.content_type', 'image/webp'),
            'Cache-Control' => (string) config('lottery_images.cache_control', 'public, max-age=31536000, immutable'),
        ]);
    }

    private function hasAllowedPrefix(string $path): bool
    {
        foreach (self::ALLOWED_PREFIXES as $prefix) {
            if (str_starts_with($path, $prefix)) {
                return true;
            }
        }

        return false;
    }
}
