<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\CentralStock\Services\CentralStockService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantStockController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly PartnerStoreService $partnerStore,
        private readonly CentralStockService $centralStock,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->partnerStore->listTenantStock((string) $context->activeTenantId(), $request->query()));
    }

    public function games(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->partnerStore->tenantStockGames((string) $context->activeTenantId()));
    }

    public function coverage(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();
        $partnerId = $this->partnerStore->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return response()->json([
                'game_id' => null,
                'scope_type' => 'partner',
                'scope_id' => null,
                'stock_mode' => 'virtual',
                'empty' => true,
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                ],
            ]);
        }

        return response()->json($this->centralStock->stockPatternSummary([
            ...$request->query(),
            'scope_type' => 'partner',
            'scope_id' => $partnerId,
        ]));
    }

    public function limitOverrides(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();
        $partnerId = $this->partnerStore->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return response()->json([
                'game_id' => $request->query('game_id'),
                'scope_type' => 'partner',
                'scope_id' => null,
                'dimension' => $request->query('dimension', 'back2'),
                'data' => [],
            ]);
        }

        return response()->json($this->centralStock->stockLimitOverrides([
            ...$request->query(),
            'scope_type' => 'partner',
            'scope_id' => $partnerId,
        ]));
    }

    public function updateLimitSettings(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $partnerId = $this->partnerIdForActiveTenant($request, $context);

        if ($partnerId === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = [
            ...$request->all(),
            'scope_type' => 'partner',
            'scope_id' => $partnerId,
        ];
        $errors = $this->centralStock->validateLimitSettingsPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->centralStock->updateStockLimitSettings($payload, $context, $request));
    }

    public function updateLimitOverrides(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $partnerId = $this->partnerIdForActiveTenant($request, $context);

        if ($partnerId === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = [
            ...$request->all(),
            'scope_type' => 'partner',
            'scope_id' => $partnerId,
        ];
        $errors = $this->centralStock->validateLimitOverridePayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->centralStock->updateStockLimitOverrides($payload, $context, $request));
    }

    public function show(Request $request, string $stock_item_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $stock = $this->partnerStore->findTenantStock((string) $context->activeTenantId(), $stock_item_id);

        return $stock === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($stock);
    }

    public function exports(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.export');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $result = $this->partnerStore->createStockExport((string) $context->activeTenantId(), $context, $request->all(), $request);

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        return response()->json($result['resource'], 202);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            $permissionCode,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function partnerIdForActiveTenant(Request $request, AdminSessionContext $context): ?string
    {
        $tenantId = (string) $context->activeTenantId();
        if ($tenantId === '') {
            return null;
        }

        return $this->partnerStore->partnerIdForTenant($tenantId);
    }
}
