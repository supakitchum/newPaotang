<?php

namespace App\Modules\Tenancy\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantConfigurationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantConfigurationService $configuration,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function settings(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settings.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $settings = $this->configuration->settingsForTenant((string) $context->activeTenantId());

        return $settings === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($settings);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $tenantId = (string) $context->activeTenantId();
        $errors = $this->configuration->validateSettingsPayload($tenantId, $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $settings = $this->configuration->updateSettings($tenantId, $payload, $context, $request);

        return $settings === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($settings);
    }

    public function theme(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settings.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $theme = $this->configuration->themeForTenant((string) $context->activeTenantId());

        return $theme === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($theme);
    }

    public function updateTheme(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $tenantId = (string) $context->activeTenantId();
        $errors = $this->configuration->validateThemePayload($tenantId, $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $theme = $this->configuration->updateTheme($tenantId, $payload, $context, $request);

        return $theme === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($theme);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
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
}
