<?php

namespace App\Modules\RewardRisk\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\RewardRisk\Services\RewardRiskAccessService;
use App\Modules\RewardRisk\Services\RewardRiskAssessmentService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantRewardRiskController extends Controller
{
    public function __construct(
        private readonly RewardRiskAssessmentService $service,
        private readonly RewardRiskAccessService $access,
        private readonly PermissionService $permissions,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function settings(Request $request): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->settings((string) $context->activeTenantId()))
            : $context;
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.manage');
        if (! $context instanceof AdminSessionContext) {
            return $context;
        }
        $errors = $this->headers->idempotencyKeyErrors($request) + $this->service->validateSettings($request->all());
        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }
        $result = $this->service->updateSettings((string) $context->activeTenantId(), $request->all(), $context, $request);
        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }
        if (isset($result['error'])) {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json($result['resource'] ?? []);
    }

    public function overview(Request $request): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->tenantOverview((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function runs(Request $request): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->listRuns((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function findings(Request $request): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->listFindings((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function finding(Request $request, string $finding_id): JsonResponse
    {
        $context = $this->authorized($request, 'reward_risk.view');
        if (! $context instanceof AdminSessionContext) {
            return $context;
        }
        $resource = $this->service->finding($finding_id, (string) $context->activeTenantId());

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    private function authorized(Request $request, string $permission): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }
        if (! $this->access->isTenantOwner($context) || ! $this->permissions->adminHasPermission(
            (string) $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            $permission,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
