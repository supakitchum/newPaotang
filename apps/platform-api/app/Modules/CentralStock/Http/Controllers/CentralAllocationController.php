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

        $replay = $this->centralStock->findAllocationReplay($context, $request);

        if ($replay !== null) {
            return response()->json($replay, 202);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateAllocationPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $allocation = $this->centralStock->createAllocation($payload, $context, $request);

        return $allocation === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($allocation, 202);
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
