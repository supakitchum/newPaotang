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

class PartnerQuotaController extends Controller
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

        return response()->json($this->centralStock->listQuotas($request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return ApiErrorResponse::make(
            $request,
            410,
            'retired_flow',
            'Partner quota writes are retired. Use partner stock percent allocation instead.',
        );
    }

    public function update(Request $request, string $quota_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return ApiErrorResponse::make(
            $request,
            410,
            'retired_flow',
            'Partner quota writes are retired. Use partner stock percent allocation instead.',
        );
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
            'partner.quota.manage',
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
