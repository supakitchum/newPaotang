<?php

namespace App\Modules\Rbac\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Rbac\Services\RoleManagementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class AdminRoleController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly RoleManagementService $roles,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function centralIndex(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'central');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json([
            'data' => $this->roles->listRoles('central', null),
            'meta' => [
                'next_cursor' => null,
                'has_more' => false,
            ],
        ]);
    }

    public function centralStore(Request $request): JsonResponse
    {
        return $this->store($request, 'central');
    }

    public function centralUpdate(Request $request, string $roleId): JsonResponse
    {
        return $this->update($request, 'central', $roleId);
    }

    public function centralDestroy(Request $request, string $roleId): Response
    {
        return $this->destroy($request, 'central', $roleId);
    }

    public function tenantIndex(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json([
            'data' => $this->roles->listRoles('tenant', $context->activeTenantId()),
        ]);
    }

    public function tenantStore(Request $request): JsonResponse
    {
        return $this->store($request, 'tenant');
    }

    public function tenantUpdate(Request $request, string $roleId): JsonResponse
    {
        return $this->update($request, 'tenant', $roleId);
    }

    public function tenantDestroy(Request $request, string $roleId): Response
    {
        return $this->destroy($request, 'tenant', $roleId);
    }

    private function store(Request $request, string $scopeType): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->roles->validatePayload($scopeType, $payload, true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->roles->conflictErrors($scopeType, $context->activeTenantId(), $payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $role = $this->roles->createRole($scopeType, $context->activeTenantId(), $payload, $context, $request);

        return response()->json($role, 201);
    }

    private function update(Request $request, string $scopeType, string $roleId): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->roles->validatePayload($scopeType, $payload, false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->roles->findRole($scopeType, $context->activeTenantId(), $roleId) === null) {
            return ApiErrorResponse::notFound($request);
        }

        if ($this->roles->conflictErrors($scopeType, $context->activeTenantId(), $payload, $roleId) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $role = $this->roles->updateRole($scopeType, $context->activeTenantId(), $roleId, $payload, $context, $request);

        if ($role === null) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($role);
    }

    private function destroy(Request $request, string $scopeType, string $roleId): Response
    {
        $context = $this->authorizedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if (! $this->roles->archiveRole($scopeType, $context->activeTenantId(), $roleId, $context, $request)) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->noContent();
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $scopeType): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            $scopeType,
            $context->activeScopeId(),
            'role.manage',
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
