<?php

namespace App\Shared\Auth\Http\Middleware;

use App\Modules\Auth\Services\AdminAuthService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Tenancy\PartnerBoHostResolver;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireAdminScope
{
    public function __construct(
        private readonly AdminAuthService $authService,
        private readonly PartnerBoHostResolver $partnerBoHosts,
    ) {
    }

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next, string $scope): Response
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! in_array($scope, ['central', 'tenant'], true)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $partnerBo = $this->partnerBoContextOrResponse($request);

        if ($partnerBo instanceof Response) {
            return $partnerBo;
        }

        if ($partnerBo !== null) {
            if ($scope === 'central' || ! $this->authService->contextMatchesPartnerBo($context, $partnerBo)) {
                return ApiErrorResponse::permissionDenied($request);
            }

            if ($request->header('X-Tenant-Id') !== $partnerBo['tenant_id']) {
                return ApiErrorResponse::permissionDenied($request);
            }
        }

        if ($request->header('X-Admin-Scope') !== $scope || $context->activeScope() !== $scope) {
            return ApiErrorResponse::permissionDenied($request);
        }

        if ($scope === 'tenant') {
            $tenantId = $request->header('X-Tenant-Id');

            if ($tenantId === null || $tenantId === '' || $context->activeTenantId() !== $tenantId) {
                return ApiErrorResponse::permissionDenied($request);
            }

            if (! $this->authService->sessionScopeIsUsable('tenant', $context->activeScopeId(), $tenantId)) {
                return ApiErrorResponse::permissionDenied($request);
            }
        }

        return $next($request);
    }

    /**
     * @return array<string, mixed>|null|Response
     */
    private function partnerBoContextOrResponse(Request $request): array|null|Response
    {
        $resolved = $this->partnerBoHosts->resolve($request);

        if ($resolved['error'] !== null) {
            return ApiErrorResponse::make(
                $request,
                $resolved['error']['status'],
                $resolved['error']['code'],
                $resolved['error']['message'],
            );
        }

        return $resolved['context'];
    }
}
