<?php

namespace App\Shared\Auth\Http\Middleware;

use App\Modules\Auth\Services\AdminAuthService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireAdminScope
{
    public function __construct(private readonly AdminAuthService $authService)
    {
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
}
