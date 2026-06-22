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

        $errors = $this->centralStock->validateAllocationPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $job = $this->centralStock->queueAllocationJob('create_allocation', $payload, $context, $request);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
    }

    public function openAllPartners(Request $request): JsonResponse
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
        $errors = $this->centralStock->validateBulkAllocationPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $job = $this->centralStock->queueAllocationJob('open_all_partners', $payload, $context, $request);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
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

        $job = $this->centralStock->queueAllocationJob('update_partner_percent', $payload, $context, $request);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
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

        $job = $this->centralStock->queueAllocationJob('cancel_allocation', $request->all(), $context, $request, $allocation_id);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
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

        $job = $this->centralStock->queueAllocationJob('recall_all', $request->all(), $context, $request, $allocation_id);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
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

        $job = $this->centralStock->queueAllocationJob('redistribute', $request->all(), $context, $request, $allocation_id);

        return ($job['error'] ?? null) === 'idempotency_conflict'
            ? ApiErrorResponse::idempotencyConflict($request)
            : response()->json($job, 202);
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
