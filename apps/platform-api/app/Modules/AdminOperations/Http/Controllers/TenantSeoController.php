<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\TenantSeoService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantSeoController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantSeoService $seo,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function settings(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $settings = $this->seo->settings((string) $context->activeTenantId());

        return $settings === null ? ApiErrorResponse::notFound($request) : response()->json($settings);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.seo.patch',
            'seo.update',
            fn (array $payload): array => $this->seo->updateSettings($tenantId, $payload, $context, $request),
        );
    }

    public function pages(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->seo->listPages((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createPage(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.seo-pages.store',
            'seo.update',
            fn (array $payload): array => $this->seo->createPage($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function updatePage(Request $request, string $page_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.seo-pages.patch:'.$page_id,
            'seo.update',
            fn (array $payload): array => $this->seo->updatePage($tenantId, $page_id, $payload, $context, $request),
        );
    }

    public function deletePage(Request $request, string $page_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.seo-pages.delete:'.$page_id,
            'seo.update',
            fn (array $payload): array => $this->seo->deletePage($tenantId, $page_id, $payload, $context, $request),
        );
    }

    public function redirects(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->seo->listRedirects((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createRedirect(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.redirect.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.redirects.store',
            'seo.redirect.manage',
            fn (array $payload): array => $this->seo->createRedirect($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function updateRedirect(Request $request, string $redirect_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.redirect.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.redirects.patch:'.$redirect_id,
            'seo.redirect.manage',
            fn (array $payload): array => $this->seo->updateRedirect($tenantId, $redirect_id, $payload, $context, $request),
        );
    }

    public function deleteRedirect(Request $request, string $redirect_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'seo.redirect.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.redirects.delete:'.$redirect_id,
            'seo.redirect.manage',
            fn (array $payload): array => $this->seo->deleteRedirect($tenantId, $redirect_id, $payload, $context, $request),
        );
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
        string $permissionCode,
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
        $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $permissionCode, true);

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

        $this->idempotency->storeResponse($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $resource, $permissionCode);

        return response()->json($resource, $status);
    }
}
