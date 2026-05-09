<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Modules\PublicSite\Services\PublicContentService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicContentController extends Controller
{
    public function __construct(private readonly PublicContentService $content)
    {
    }

    public function seoPage(Request $request): JsonResponse
    {
        return $this->result($request, $this->content->seoPage($request));
    }

    public function news(Request $request): JsonResponse
    {
        return $this->result($request, $this->content->news($request));
    }

    public function stores(Request $request): JsonResponse
    {
        return $this->result($request, $this->content->stores($request));
    }

    /**
     * @param array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}} $result
     */
    private function result(Request $request, array $result): JsonResponse
    {
        if (isset($result['error'])) {
            if ($result['error']['code'] === 'validation_failed') {
                return ApiErrorResponse::validationFailed($request, ['path' => [$result['error']['message']]]);
            }

            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return response()->json($result['resource'] ?? []);
    }
}
