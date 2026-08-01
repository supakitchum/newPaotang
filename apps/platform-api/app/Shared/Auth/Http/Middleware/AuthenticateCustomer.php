<?php

namespace App\Shared\Auth\Http\Middleware;

use App\Models\CustomerAccountDeletionRequest;
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
            $failure = $this->sessions->failure();

            if ($failure !== null) {
                return ApiErrorResponse::make(
                    $request,
                    401,
                    $failure['code'],
                    $failure['message'],
                    $failure['details'],
                );
            }

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

        if ($this->blocksPendingDeletion($request, $context->tenantId(), $context->customerId())) {
            $deletion = CustomerAccountDeletionRequest::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->whereIn('status', ['pending', 'blocked'])
                ->first();

            return ApiErrorResponse::make(
                $request,
                423,
                'account_deletion_pending',
                'This account is read-only while deletion is pending.',
                [
                    'status' => $deletion?->status,
                    'scheduled_for' => $deletion?->scheduled_for?->toISOString(),
                    'route' => '/profile/account-deletion',
                ],
            );
        }

        return $next($request);
    }

    private function blocksMaintenance(Request $request): bool
    {
        return $request->is(
            'api/v1/customer/auth/logout',
            'api/v1/customer/auth/me',
            'api/v1/customer/auth/pin/*',
            'api/v1/customer/profile',
            'api/v1/customer/account-deletion*',
        );
    }

    private function blocksPendingDeletion(Request $request, string $tenantId, string $customerId): bool
    {
        if ($request->isMethod('GET') || ! CustomerAccountDeletionRequest::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->whereIn('status', ['pending', 'blocked'])
            ->exists()) {
            return false;
        }

        return ! $request->is(
            'api/v1/customer/account-deletion*',
            'api/v1/customer/auth/logout',
            'api/v1/customer/auth/refresh',
            'api/v1/customer/auth/me',
            'api/v1/customer/auth/pin/*',
            'api/v1/customer/notifications/*/read',
            'api/v1/customer/notifications/read-all',
            'api/v1/customer/realtime/auth',
            'api/v1/customer/support-session',
        );
    }

    private function requiresPinUnlock(Request $request): bool
    {
        if ($request->is(
            'api/v1/customer/auth/biometric/challenge',
            'api/v1/customer/auth/biometric/verify',
        )) {
            return false;
        }

        if ($request->isMethod('GET') && $request->is('api/v1/customer/auth/biometric/devices')) {
            return false;
        }

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
