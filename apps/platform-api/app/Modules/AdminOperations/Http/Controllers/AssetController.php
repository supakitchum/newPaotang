<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\AssetService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AssetController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly AssetService $assets,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function centralUpload(Request $request): JsonResponse
    {
        $context = $this->centralContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.assets.uploads',
            fn (array $payload): array => $this->assets->createUploadIntent('central', null, $payload, $context, $request),
            201,
        );
    }

    public function centralShow(Request $request, string $asset_id): JsonResponse
    {
        $context = $this->centralContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $asset = $this->assets->findAsset('central', null, $asset_id);

        return $asset === null ? ApiErrorResponse::notFound($request) : response()->json($asset);
    }

    public function centralCommit(Request $request, string $asset_id): JsonResponse
    {
        $context = $this->centralContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.assets.commit:'.$asset_id,
            fn (array $payload): array => $this->assets->commitAsset('central', null, $asset_id, $payload, $context, $request),
        );
    }

    public function tenantUpload(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.assets.uploads',
            fn (array $payload): array => $this->assets->createUploadIntent('tenant', $tenantId, $payload, $context, $request),
            201,
        );
    }

    public function tenantShow(Request $request, string $asset_id): JsonResponse
    {
        $context = $this->tenantContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $asset = $this->assets->findAsset('tenant', (string) $context->activeTenantId(), $asset_id);

        return $asset === null ? ApiErrorResponse::notFound($request) : response()->json($asset);
    }

    public function tenantCommit(Request $request, string $asset_id): JsonResponse
    {
        $context = $this->tenantContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.assets.commit:'.$asset_id,
            fn (array $payload): array => $this->assets->commitAsset('tenant', $tenantId, $asset_id, $payload, $context, $request),
        );
    }

    private function centralContext(Request $request): AdminSessionContext|JsonResponse
    {
        return $this->authorizedContext($request, 'central', null);
    }

    private function tenantContext(Request $request): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if ($context instanceof AdminSessionContext && ($context->activeTenantId() === null || $context->activeTenantId() === '')) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $this->authorizedContext($request, 'tenant', $context instanceof AdminSessionContext ? $context->activeTenantId() : null);
    }

    private function authorizedContext(Request $request, string $scopeType, ?string $tenantId): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== $scopeType) {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            $scopeType,
            $context->activeScopeId(),
            'asset.manage',
            $tenantId,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function writeWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        ?string $tenantId,
        string $actorType,
        string $routeKey,
        callable $callback,
        int $defaultStatus = 200,
    ): JsonResponse {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict($tenantId, $actorType, (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, 'asset.manage', true);

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

        if (($result['error'] ?? null) === 'blocked_external') {
            return ApiErrorResponse::make($request, 503, 'blocked_external', 'Object storage signing is blocked until Coordinator/Ops approves production R2/CDN policy.');
        }

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $status = $result['status'] ?? $defaultStatus;
        $resource = $result['resource'] ?? [];

        $this->idempotency->storeResponse($tenantId, $actorType, (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $resource, 'asset.manage');

        return response()->json($resource, $status);
    }
}
