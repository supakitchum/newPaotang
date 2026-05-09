<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantStockSyncController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly PartnerStoreService $partnerStore,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->partnerStore->listStockSyncBatches((string) $context->activeTenantId(), $request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $tenantId = (string) $context->activeTenantId();
        $partnerId = $this->partnerStore->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return ApiErrorResponse::notFound($request);
        }

        $result = $this->partnerStore->createStockSyncBatch($tenantId, $partnerId, $context, $request->all(), $request);

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        return response()->json($result['resource'], 202);
    }

    public function show(Request $request, string $batch_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $batch = $this->partnerStore->findStockSyncBatch((string) $context->activeTenantId(), $batch_id);

        return $batch === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($batch);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            'stock.sync',
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
