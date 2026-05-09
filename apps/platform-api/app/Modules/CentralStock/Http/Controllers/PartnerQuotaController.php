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

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateQuotaPayload($payload, true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->centralStock->quotaConflictErrors($payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json($this->centralStock->createQuota($payload, $context, $request), 201);
    }

    public function update(Request $request, string $quota_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findQuota($quota_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateQuotaPayload($payload, false, $quota_id);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->centralStock->quotaConflictErrors($payload, $quota_id) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $quota = $this->centralStock->updateQuota($quota_id, $payload, $context, $request);

        return $quota === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($quota);
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
