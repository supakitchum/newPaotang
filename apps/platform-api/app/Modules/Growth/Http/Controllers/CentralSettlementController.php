<?php

namespace App\Modules\Growth\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Growth\Services\GrowthService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Growth\Http\Requests\GrowthRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralSettlementController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly GrowthService $growth,
        private readonly RequestHeaderValidator $headers,
        private readonly GrowthRequestValidator $validator,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settlement.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listSettlements($request->query()))
            : $context;
    }

    public function show(Request $request, string $settlement_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settlement.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $settlement = $this->growth->settlement($settlement_id);

        return $settlement === null ? ApiErrorResponse::notFound($request) : response()->json($settlement);
    }

    public function approve(Request $request, string $settlement_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'settlement.approve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payloadErrors = $this->validator->optionalApprovalReasonErrors($request->all());

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        $result = $this->growth->approveSettlement($context, $settlement_id, $request->all(), $request);

        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? 200),
        };
    }

    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission($context->adminUser['id'], 'central', $context->activeScopeId(), $permissionCode)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
