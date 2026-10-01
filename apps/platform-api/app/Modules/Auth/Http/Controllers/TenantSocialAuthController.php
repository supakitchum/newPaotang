<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\TenantSocialAuthService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantSocialAuthController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantSocialAuthService $providers,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'social_login.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->providers->settings((string) $context->activeTenantId()))
            : $context;
    }

    public function update(Request $request, string $provider): JsonResponse
    {
        $context = $this->tenantContext($request, 'social_login.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->providers->update((string) $context->activeTenantId(), $provider, $request->all()))
            : $context;
    }

    public function disconnect(Request $request, string $provider): JsonResponse
    {
        $context = $this->tenantContext($request, 'social_login.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->providers->disconnect((string) $context->activeTenantId(), $provider))
            : $context;
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== 'tenant' || $context->activeTenantId() === null || $context->activeTenantId() === '') {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            $permissionCode,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    /**
     * @param array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'provider_managed_elsewhere' => ApiErrorResponse::make($request, 409, 'provider_managed_elsewhere', 'This provider is managed from another settings page.'),
            'line_encryption_not_configured', 'line_encryption_failed', 'line_schema_not_ready' => ApiErrorResponse::make(
                $request,
                503,
                (string) $result['error'],
                (string) ($result['message'] ?? 'Unable to save LINE Login settings.'),
                $result['details'] ?? [],
            ),
            default => response()->json($result['resource'] ?? []),
        };
    }
}
