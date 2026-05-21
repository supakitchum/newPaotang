<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicSiteConfigController extends Controller
{
    public function __construct(private readonly TenantConfigurationService $configuration)
    {
    }

    public function show(Request $request): JsonResponse
    {
        $result = $this->configuration->siteConfigForRequest($request);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return response()->json(['data' => $result['data']]);
    }

    public function admin(Request $request): JsonResponse
    {
        $result = $this->configuration->adminSiteConfigForRequest($request);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return response()->json($result['data']);
    }
}
