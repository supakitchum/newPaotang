<?php

namespace App\Modules\Activities\Http\Controllers;

use App\Modules\Activities\Services\TenantActivityService;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicActivityController extends Controller
{
    public function __construct(
        private readonly TenantConfigurationService $configuration,
        private readonly TenantActivityService $activities,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return $this->error($request, $site['error']);
        }

        return response()->json($this->activities->publicList((string) $site['data']['tenant_id'], $request->query()));
    }

    public function show(Request $request, string $slug): JsonResponse
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return $this->error($request, $site['error']);
        }

        $activity = $this->activities->publicFindBySlug((string) $site['data']['tenant_id'], $slug);

        return $activity === null
            ? ApiErrorResponse::make($request, 404, 'activity_not_found', 'Activity was not found.')
            : response()->json($activity);
    }

    /**
     * @return array{data?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    private function siteConfig(Request $request): array
    {
        return $this->configuration->siteConfigForRequest($request);
    }

    /**
     * @param array{status: int, code: string, message: string} $error
     */
    private function error(Request $request, array $error): JsonResponse
    {
        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }

}
