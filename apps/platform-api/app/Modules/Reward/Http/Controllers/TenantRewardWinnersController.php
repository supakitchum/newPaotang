<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Reward\Services\RewardService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantRewardWinnersController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly RewardService $rewards,
    ) {
    }

    public function winners(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->rewards->listTenantWinners((string) $context->activeTenantId(), $request->query()));
    }

    public function winnerGames(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->rewards->tenantWinnerGames((string) $context->activeTenantId()));
    }

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
            'reward_claim.view',
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
