<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\TenantAnnouncementService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantAnnouncementController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantAnnouncementService $announcements,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->announcements->list((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function show(Request $request, string $announcement_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $announcement = $this->announcements->find((string) $context->activeTenantId(), $announcement_id);

        return $announcement === null ? ApiErrorResponse::notFound($request) : response()->json($announcement);
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.announcements.store',
            fn (array $payload): array => $this->announcements->create((string) $context->activeTenantId(), $payload, $context, $request),
            201,
        );
    }

    public function update(Request $request, string $announcement_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.announcements.patch:'.$announcement_id,
            fn (array $payload): array => $this->announcements->update((string) $context->activeTenantId(), $announcement_id, $payload, $context, $request),
        );
    }

    public function destroy(Request $request, string $announcement_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.announcements.delete:'.$announcement_id,
            fn (array $payload): array => $this->announcements->delete((string) $context->activeTenantId(), $announcement_id, $payload, $context, $request),
        );
    }

    public function uploadImage(Request $request, string $announcement_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'announcement.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->announcements->uploadImage((string) $context->activeTenantId(), $announcement_id, $request->file('file'), $context, $request);

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['file' => ['The upload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'] ?? []);
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

    private function writeWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $routeKey,
        callable $callback,
        int $defaultStatus = 200,
    ): JsonResponse {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $tenantId = (string) $context->activeTenantId();
        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, 'announcement.manage', true);

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $result = $callback($payload);

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        $status = $result['status'] ?? $defaultStatus;
        $resource = $result['resource'] ?? [];

        $this->idempotency->storeResponse($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $resource, 'announcement.manage');

        return response()->json($resource, $status);
    }
}
