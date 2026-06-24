<?php

namespace App\Shared\Auth\Http\Middleware;

use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionResolver;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateCustomer
{
    public function __construct(
        private readonly CustomerSessionResolver $sessions,
        private readonly PartnerStoreService $partnerStore,
    ) {
    }

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $tenant = $this->partnerStore->tenantContextForRequest($request, $this->blocksMaintenance($request));

        if (isset($tenant['error'])) {
            return $this->tenantError($request, $tenant['error']);
        }

        $tenantId = (string) $tenant['context']['tenant_id'];
        $tokenTenantId = $this->sessions->accessTokenTenantId($request->bearerToken());

        if ($tokenTenantId === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($tokenTenantId !== $tenantId) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $context = $this->sessions->resolveAccessToken($request->bearerToken(), $tenantId);

        if ($context === null) {
            $suspension = $this->sessions->suspendedCustomerForAccessToken($request->bearerToken(), $tenantId);

            if ($suspension !== null) {
                return ApiErrorResponse::customerSuspended($request, $suspension);
            }

            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($this->requiresPinUnlock($request)) {
            if (! $context->hasPin()) {
                return ApiErrorResponse::customerPinSetupRequired($request);
            }

            if (! $context->pinVerified()) {
                return ApiErrorResponse::customerPinRequired($request);
            }
        }

        $request->attributes->set('customer_session', $context);
        $request->attributes->set('customer_tenant', $tenant['context']);

        return $next($request);
    }

    private function blocksMaintenance(Request $request): bool
    {
        return $request->is(
            'api/v1/customer/auth/logout',
            'api/v1/customer/auth/me',
            'api/v1/customer/auth/pin/*',
            'api/v1/customer/profile',
        );
    }

    private function requiresPinUnlock(Request $request): bool
    {
        return ! $request->is(
            'api/v1/customer/auth/logout',
            'api/v1/customer/auth/me',
            'api/v1/customer/auth/pin/status',
            'api/v1/customer/auth/pin/setup',
            'api/v1/customer/auth/pin/verify',
            'api/v1/customer/auth/pin/change',
            'api/v1/customer/auth/pin/reset',
            'api/v1/customer/auth/pin/reset/verify-password',
            'api/v1/customer/auth/pin/reset/request-otp',
            'api/v1/customer/auth/pin/reset/verify-otp',
            'api/v1/customer/auth/pin/reset/confirm-otp',
            'api/v1/customer/affiliate/referrals/apply',
        );
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): Response
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }
}
