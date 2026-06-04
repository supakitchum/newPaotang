<?php

namespace App\Modules\Activities\Http\Controllers;

use App\Modules\Activities\Services\TenantActivityService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantActivityController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantActivityService $activities,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->activities->list((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function show(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $activity = $this->activities->find((string) $context->activeTenantId(), $activity_id);

        return $activity === null ? ApiErrorResponse::notFound($request) : response()->json($activity);
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.activities.store',
            fn (array $payload): array => $this->activities->create((string) $context->activeTenantId(), $payload, $context, $request),
            201,
        );
    }

    public function update(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.activities.patch:'.$activity_id,
            fn (array $payload): array => $this->activities->update((string) $context->activeTenantId(), $activity_id, $payload, $context, $request),
        );
    }

    public function destroy(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            'admin.tenant.activities.delete:'.$activity_id,
            fn (array $payload): array => $this->activities->delete((string) $context->activeTenantId(), $activity_id, $payload, $context, $request),
        );
    }

    public function uploadImage(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->activities->uploadImage((string) $context->activeTenantId(), $activity_id, $request->file('file'), $context, $request);

        return $this->serviceResult($request, $result);
    }

    public function entries(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->activities->tenantEntries((string) $context->activeTenantId(), $activity_id, $request->query()))
            : $context;
    }

    public function awards(Request $request, string $activity_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->activities->tenantAwards((string) $context->activeTenantId(), $activity_id, $request->query()))
            : $context;
    }

    public function claims(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->activities->tenantClaims((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function claim(Request $request, string $claim_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'activity.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $claim = $this->activities->tenantClaim((string) $context->activeTenantId(), $claim_id);

        return $claim === null ? ApiErrorResponse::notFound($request) : response()->json($claim);
    }

    public function approveClaim(Request $request, string $claim_id): JsonResponse
    {
        return $this->claimAction($request, $claim_id, 'activity.manage', fn (AdminSessionContext $context): array => $this->activities->approveTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all()));
    }

    public function rejectClaim(Request $request, string $claim_id): JsonResponse
    {
        return $this->claimAction($request, $claim_id, 'activity.manage', fn (AdminSessionContext $context): array => $this->activities->rejectTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all()));
    }

    public function payClaim(Request $request, string $claim_id): JsonResponse
    {
        return $this->claimAction($request, $claim_id, 'activity.manage', fn (AdminSessionContext $context): array => $this->activities->payTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all()));
    }

    private function claimAction(Request $request, string $claimId, string $permission, callable $callback): JsonResponse
    {
        $context = $this->tenantContext($request, $permission);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->serviceResult($request, $callback($context));
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
        $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, 'activity.manage', true);

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

        if (($result['error'] ?? null) === null) {
            $status = $result['status'] ?? $defaultStatus;
            $resource = $result['resource'] ?? [];
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $resource, 'activity.manage');

            return response()->json($resource, $status);
        }

        return $this->serviceResult($request, $result);
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $result
     */
    private function serviceResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
