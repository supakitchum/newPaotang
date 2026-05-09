<?php

namespace App\Modules\Rbac\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\AdminUserManagementService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class AdminUserController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly AdminUserManagementService $adminUsers,
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
            'data' => $this->adminUsers->listUsers('central', null),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ]);
    }

    public function centralStore(Request $request): JsonResponse
    {
        return $this->store($request, 'central');
    }

    public function centralShow(Request $request, string $admin_user_id): JsonResponse
    {
        return $this->show($request, 'central', $admin_user_id);
    }

    public function centralUpdate(Request $request, string $admin_user_id): JsonResponse
    {
        return $this->update($request, 'central', $admin_user_id);
    }

    public function centralDestroy(Request $request, string $admin_user_id): Response
    {
        return $this->destroy($request, 'central', $admin_user_id);
    }

    public function tenantIndex(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json([
            'data' => $this->adminUsers->listUsers('tenant', $context->activeTenantId()),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ]);
    }

    public function tenantStore(Request $request): JsonResponse
    {
        return $this->store($request, 'tenant');
    }

    public function tenantShow(Request $request, string $admin_user_id): JsonResponse
    {
        return $this->show($request, 'tenant', $admin_user_id);
    }

    public function tenantUpdate(Request $request, string $admin_user_id): JsonResponse
    {
        return $this->update($request, 'tenant', $admin_user_id);
    }

    public function tenantDestroy(Request $request, string $admin_user_id): Response
    {
        return $this->destroy($request, 'tenant', $admin_user_id);
    }

    private function show(Request $request, string $scopeType, string $adminUserId): JsonResponse
    {
        $context = $this->authorizedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $user = $this->adminUsers->findUser($scopeType, $context->activeTenantId(), $adminUserId);

        if ($user === null) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($user);
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
        $errors = $this->adminUsers->validatePayload($scopeType, $context->activeTenantId(), $payload, true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->adminUsers->conflictErrors($scopeType, $context->activeTenantId(), $payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json(
            $this->adminUsers->createUser($scopeType, $context->activeTenantId(), $payload, $context, $request),
            201,
        );
    }

    private function update(Request $request, string $scopeType, string $adminUserId): JsonResponse
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
        $errors = $this->adminUsers->validatePayload($scopeType, $context->activeTenantId(), $payload, false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->adminUsers->findUser($scopeType, $context->activeTenantId(), $adminUserId) === null) {
            return ApiErrorResponse::notFound($request);
        }

        if ($this->adminUsers->conflictErrors($scopeType, $context->activeTenantId(), $payload, $adminUserId) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $user = $this->adminUsers->updateUser($scopeType, $context->activeTenantId(), $adminUserId, $payload, $context, $request);

        if ($user === null) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($user);
    }

    private function destroy(Request $request, string $scopeType, string $adminUserId): Response
    {
        $context = $this->authorizedContext($request, $scopeType);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if (! $this->adminUsers->disableUser($scopeType, $context->activeTenantId(), $adminUserId, $context, $request)) {
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
            'admin_user.manage',
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
