<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerLineAuthService;
use App\Modules\Auth\Services\CustomerSocialAuthService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSessionResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerSocialAuthController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly CustomerSocialAuthService $socialAuth,
        private readonly CustomerLineAuthService $lineAuth,
        private readonly CustomerSessionResolver $sessions,
    ) {
    }

    public function login(Request $request, string $provider): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $provider = strtolower(trim($provider));
        $result = $provider === 'line'
            ? $this->lineAuth->redirect($tenant, $request->all(), $request)
            : $this->socialAuth->redirect($tenant, $provider, $request->all(), $request);

        return $this->result($request, $result, $provider);
    }

    public function callback(Request $request, string $provider): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $provider = strtolower(trim($provider));
        $currentCustomer = $this->optionalCustomerContext($request, (string) $tenant['tenant_id']);
        $callbackPayload = array_merge($request->query(), $request->request->all());
        $result = $provider === 'line'
            ? $this->lineAuth->callback($tenant, $callbackPayload, $request, $currentCustomer)
            : $this->socialAuth->callback($tenant, $provider, $callbackPayload, $request, $currentCustomer);

        return $this->result($request, $result, $provider);
    }

    public function linkPhone(Request $request, string $provider): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $provider = strtolower(trim($provider));
        $result = $provider === 'line'
            ? $this->lineAuth->linkPhone($tenant, $request->all())
            : $this->socialAuth->linkPhone($tenant, $provider, $request->all());

        return $this->result($request, $result, $provider);
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
     * @param array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>, errors?: array<string, array<int, string>>} $result
     */
    private function result(Request $request, array $result, string $provider): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['details']['fields'] ?? $result['errors'] ?? []),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'customer_suspended' => ApiErrorResponse::customerSuspended($request, $result['details'] ?? []),
            'social_identity_not_linked', 'line_identity_not_linked' => ApiErrorResponse::make(
                $request,
                422,
                (string) $result['error'],
                strtoupper($provider).' account is not linked to a customer account.',
                $result['details'] ?? [],
            ),
            'provider_exchange_failed' => ApiErrorResponse::make(
                $request,
                422,
                $result['error'],
                strtoupper($provider).' login could not be completed.',
                $result['details'] ?? [],
            ),
            'provider_not_supported' => ApiErrorResponse::notFound($request),
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

    private function optionalCustomerContext(Request $request, string $tenantId): ?CustomerSessionContext
    {
        return $this->sessions->resolveAccessToken($request->bearerToken(), $tenantId);
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
