<?php

namespace App\Modules\CentralStock\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\CentralStock\Services\CentralStockService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralAllocationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CentralStockService $centralStock,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->listAllocations($request->query()));
    }

    public function partnerOptions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->allocationPartnerOptions($request->query()));
    }

    public function tenantOptions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->allocationTenantOptions($request->query()));
    }

    public function gameOptions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->allocationGameOptions($request->query()));
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

        $payload = $request->all();
        if (array_key_exists('requested_count', $payload)) {
            return ApiErrorResponse::validationFailed($request, [
                'requested_count' => ['The requested_count field is retired for allocation create. Use allocation_percent.'],
            ]);
        }

        $replay = $this->centralStock->findAllocationReplay($context, $request, $payload);

        if (($replay['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay !== null) {
            return response()->json($replay, 202);
        }

        $errors = $this->centralStock->validateAllocationPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $allocation = $this->centralStock->createAllocation($payload, $context, $request);

        return $allocation === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($allocation, 202);
    }

    public function updatePartnerPercent(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validatePartnerPercentPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $resource = $this->centralStock->updatePartnerPercent($payload, $context, $request);

        return $resource === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($resource);
    }

    public function show(Request $request, string $allocation_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $allocation = $this->centralStock->findAllocation($allocation_id);

        return $allocation === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($allocation);
    }

    public function cancel(Request $request, string $allocation_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findAllocation($allocation_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $allocation = $this->centralStock->cancelAllocation($allocation_id, $request->all(), $context, $request);

        return $allocation === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($allocation);
    }

    public function recallAll(Request $request, string $allocation_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findAllocation($allocation_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $allocation = $this->centralStock->recallAllAllocation($allocation_id, $request->all(), $context, $request);

        return $allocation === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($allocation);
    }

    public function redistribute(Request $request, string $allocation_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findAllocation($allocation_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $allocation = $this->centralStock->redistributeAllocation($allocation_id, $request->all(), $context, $request);

        return $allocation === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($allocation);
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
            'central',
            $context->activeScopeId(),
            'stock.allocate',
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
