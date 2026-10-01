<?php

namespace App\Modules\RewardRisk\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\RewardRisk\Services\RewardRiskAccessService;
use App\Modules\RewardRisk\Services\RewardRiskAssessmentService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralRewardRiskController extends Controller
{
    public function __construct(
        private readonly RewardRiskAssessmentService $service,
        private readonly RewardRiskAccessService $access,
        private readonly PermissionService $permissions,
    ) {
    }

    public function overview(Request $request): JsonResponse
    {
        $context = $this->authorized($request);

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->centralOverview($request->query()))
            : $context;
    }

    public function runs(Request $request): JsonResponse
    {
        $context = $this->authorized($request);

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->listRuns(null, $request->query()))
            : $context;
    }

    public function findings(Request $request): JsonResponse
    {
        $context = $this->authorized($request);

        return $context instanceof AdminSessionContext
            ? response()->json($this->service->listFindings(null, $request->query(), true))
            : $context;
    }

    public function finding(Request $request, string $finding_id): JsonResponse
    {
        $context = $this->authorized($request);
        if (! $context instanceof AdminSessionContext) {
            return $context;
        }
        $resource = $this->service->finding($finding_id, null, true);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    private function authorized(Request $request): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }
        if (! $this->access->isCentralSuperAdmin($context) || ! $this->permissions->adminHasPermission(
            (string) $context->adminUser['id'],
            'central',
            $context->activeScopeId(),
            'reward_risk.view',
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
