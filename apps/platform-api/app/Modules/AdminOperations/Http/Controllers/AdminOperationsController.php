<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\AdminOperationsService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\MenuManagementService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AdminOperationsController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly AdminOperationsService $operations,
        private readonly MenuManagementService $menuManagement,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function centralDashboardSummary(Request $request): JsonResponse
    {
        return $this->dashboardSummary($request, 'central');
    }

    public function tenantDashboardSummary(Request $request): JsonResponse
    {
        return $this->dashboardSummary($request, 'tenant');
    }

    public function centralRealtimeAuth(Request $request): JsonResponse
    {
        return $this->realtimeAuth($request, 'central');
    }

    public function tenantRealtimeAuth(Request $request): JsonResponse
    {
        return $this->realtimeAuth($request, 'tenant');
    }

    public function centralMenuManagement(Request $request): JsonResponse
    {
        return $this->menuManagementTree($request, 'central');
    }

    public function tenantMenuManagement(Request $request): JsonResponse
    {
        return $this->menuManagementTree($request, 'tenant');
    }

    public function centralUpdateMenuManagement(Request $request): JsonResponse
    {
        return $this->updateMenuManagementTree($request, 'central');
    }

    public function tenantUpdateMenuManagement(Request $request): JsonResponse
    {
        return $this->updateMenuManagementTree($request, 'tenant');
    }

    public function centralAuditLogs(Request $request): JsonResponse
    {
        return $this->auditLogs($request, 'central');
    }

    public function tenantAuditLogs(Request $request): JsonResponse
    {
        return $this->auditLogs($request, 'tenant');
    }

    private function dashboardSummary(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType, 'dashboard.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->operations->dashboardSummary($scopeType, $context->activeTenantId()));
    }

    private function realtimeAuth(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->scopedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $errors = $this->operations->realtimeValidationErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $authorization = $this->operations->realtimeAuth($context, $scopeType, $payload);

        if ($authorization === null) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return response()->json($authorization);
    }

    private function menuManagementTree(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType, 'menu.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json([
            'data' => $this->menuManagement->manageableTree($scopeType, $context->activeTenantId()),
        ]);
    }

    private function updateMenuManagementTree(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType, 'menu.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->menuManagement->validateUpdate($scopeType, $context->activeTenantId(), $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json([
            'data' => $this->menuManagement->updateTree($scopeType, $context->activeTenantId(), $payload, $context, $request),
        ]);
    }

    private function auditLogs(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType, 'audit.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->operations->auditLogs($scopeType, $context->activeTenantId(), $request->query()));
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $scopeType, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $this->scopedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            $scopeType,
            $context->activeScopeId(),
            $permissionCode,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function scopedContext(Request $request, string $scopeType): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== $scopeType) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
