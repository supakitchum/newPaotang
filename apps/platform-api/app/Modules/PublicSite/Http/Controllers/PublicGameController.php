<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicGameController extends Controller
{
    public function __construct(private readonly PartnerStoreService $partnerStore)
    {
    }

    public function current(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $game = $this->partnerStore->currentGameForTenant($tenant['tenant_id']);

        return $game === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($game);
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): JsonResponse
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }
}
