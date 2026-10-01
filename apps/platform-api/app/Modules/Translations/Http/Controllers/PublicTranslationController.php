<?php

namespace App\Modules\Translations\Http\Controllers;

use App\Modules\Translations\Services\SystemTranslationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicTranslationController extends Controller
{
    public function __construct(private readonly SystemTranslationService $translations)
    {
    }

    public function bundle(Request $request): JsonResponse
    {
        $locale = $request->query('locale') ?: $request->header('X-Locale') ?: $request->header('Accept-Language');
        $surface = $request->query('surface') ?: 'customer';
        $previewToken = $request->query('preview_token') ?: $request->header('X-Translation-Preview');
        $bundle = $this->translations->runtimeBundle(is_string($locale) ? $locale : null, is_string($surface) ? $surface : null, is_string($previewToken) ? $previewToken : null);

        return response()
            ->json($bundle)
            ->header('Content-Language', $bundle['locale'])
            ->header('Vary', 'Accept-Language');
    }
}
