<?php

namespace App\Modules\Pricing\Http\Controllers;

use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AdminSalePriceRuleController extends Controller
{
    public function __construct(
        private readonly LotterySalePriceService $prices,
        private readonly PermissionService $permissions,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function centralIndex(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'central', 'price_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->prices->listCentralRules($request->query()))
            : $context;
    }

    public function centralStore(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'central', 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $result = $this->prices->upsertCentralRule($request->all());

        return $this->writeResult($request, $result, 201);
    }

    public function centralShow(Request $request, string $sale_price_rule_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'central', 'price_rule.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->prices->findCentralRule($sale_price_rule_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function centralUpdate(Request $request, string $sale_price_rule_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'central', 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->prices->findCentralRule($sale_price_rule_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        return $this->writeResult($request, $this->prices->upsertCentralRule($request->all(), $sale_price_rule_id));
    }

    public function tenantIndex(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant', 'price_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->prices->listTenantRules((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function tenantStore(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant', 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult(
            $request,
            $this->prices->upsertTenantRule((string) $context->activeTenantId(), $request->all()),
            201,
        );
    }

    public function tenantShow(Request $request, string $sale_price_rule_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant', 'price_rule.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->prices->findTenantRule((string) $context->activeTenantId(), $sale_price_rule_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function tenantUpdate(Request $request, string $sale_price_rule_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'tenant', 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult(
            $request,
            $this->prices->upsertTenantRule((string) $context->activeTenantId(), $request->all(), $sale_price_rule_id),
        );
    }

    public function gameOptions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, $request->is('api/v1/admin/central/*') ? 'central' : 'tenant', 'price_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->prices->gameOptions())
            : $context;
    }

    /**
     * @param array{resource?: array<string, mixed>|null, errors?: array<string, array<int, string>>, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $successStatus = 200): JsonResponse
    {
        if (($result['errors'] ?? []) !== []) {
            return ApiErrorResponse::validationFailed($request, $result['errors']);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'], $successStatus);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $scope, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            $scope,
            $context->activeScopeId(),
            $permissionCode,
            $scope === 'tenant' ? $context->activeTenantId() : null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
