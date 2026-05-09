<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerLineAuthService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerLineAuthController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly CustomerLineAuthService $lineAuth,
    ) {
    }

    public function login(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $result = $this->lineAuth->redirect($tenant, $request->all(), $request);

        return $this->result($request, $result);
    }

    public function callback(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $result = $this->lineAuth->callback($tenant, $request->query(), $request);

        return $this->result($request, $result);
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
     * @param array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>} $result
     */
    private function result(Request $request, array $result): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['details']['fields'] ?? []),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'provider_not_configured', 'provider_exchange_blocked' => ApiErrorResponse::make(
                $request,
                503,
                $result['error'],
                'External login provider is not ready.',
                $result['details'] ?? [],
            ),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? 200),
        };
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
