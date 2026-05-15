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

class CentralStockController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
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

        return response()->json($this->centralStock->listStock($request->query()));
    }

    public function summary(Request $request): JsonResponse
    {
        $context = $this->authorizedAnyContext($request, ['stock.view', 'stock.generate']);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->stockSummary($request->query()));
    }

    public function generate(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.generate');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateGeneratePayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->centralStock->generateStock($payload, $context, $request);

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        return response()->json($result, 202);
    }

    public function generationBatches(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.generate');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->listGenerationBatches($request->query()));
    }

    public function generationBatch(Request $request, string $batch_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.generate');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $batch = $this->centralStock->findGenerationBatch($batch_id);

        return $batch === null ? ApiErrorResponse::notFound($request) : response()->json($batch);
    }

    public function imports(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.generate');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateImportPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->centralStock->importStock($payload, $context, $request);

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        return response()->json($result, 202);
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

        $payload = $request->all();
        $errors = $this->centralStock->validateExportPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->centralStock->createStockExport($payload, $context, $request), 202);
    }

    public function recall(Request $request, string $stock_item_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'stock.recall');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findStock($stock_item_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $stock = $this->centralStock->recallStock($stock_item_id, $request->all(), $context, $request);

        return $stock === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($stock, 202);
    }

    /**
     * @param array<int, string> $permissionCodes
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedAnyContext(Request $request, array $permissionCodes): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        foreach ($permissionCodes as $permissionCode) {
            if ($this->permissions->adminHasPermission(
                $context->adminUser['id'],
                'central',
                $context->activeScopeId(),
                $permissionCode,
                null,
            )) {
                return $context;
            }
        }

        return ApiErrorResponse::permissionDenied($request);
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
            'central',
            $context->activeScopeId(),
            $permissionCode,
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
