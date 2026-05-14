<?php

namespace App\Modules\CentralStock\Http\Controllers;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class LotteryImageOperationsController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly LotteryImageOperationsService $operations,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function readiness(Request $request): JsonResponse
    {
        return $this->read($request, 'stock.view', fn (): array => $this->operations->readiness($request->query()));
    }

    public function backgroundSets(Request $request): JsonResponse
    {
        return $this->read($request, 'asset.manage', fn (): array => $this->operations->listBackgroundSets($request->query()));
    }

    public function upsertBackgroundSet(Request $request): JsonResponse
    {
        return $this->write(
            $request,
            'asset.manage',
            'admin.central.lottery-images.background-asset-sets.upsert',
            fn (AdminSessionContext $context, array $payload): array => $this->operations->upsertBackgroundSet($payload, $context, $request),
        );
    }

    public function updateBackgroundSetStatus(Request $request, string $asset_set_id): JsonResponse
    {
        return $this->write(
            $request,
            'asset.manage',
            'admin.central.lottery-images.background-asset-sets.status:'.$asset_set_id,
            fn (AdminSessionContext $context, array $payload): array => $this->operations->updateBackgroundSetStatus($asset_set_id, $payload, $context, $request),
        );
    }

    public function importBackgroundZip(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'asset.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $file = $request->file('zip') ?? $request->file('file');
        $payload = $request->except(['zip', 'file']);
        $idempotencyPayload = $payload;
        unset($idempotencyPayload['expected_count']);

        if ($file instanceof \Illuminate\Http\UploadedFile && $file->isValid()) {
            $realPath = $file->getRealPath();
            $idempotencyPayload['zip'] = [
                'name' => $file->getClientOriginalName(),
                'size' => $file->getSize(),
                'sha256' => is_string($realPath) ? hash_file('sha256', $realPath) : null,
            ];
        }

        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $routeKey = 'admin.central.lottery-images.background-asset-sets.import-zip';
        $replay = $this->idempotency->replayOrConflict(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $idempotencyPayload,
            'asset.manage',
            true,
        );

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $result = $this->operations->importBackgroundZip($payload, $file instanceof \Illuminate\Http\UploadedFile ? $file : null, $context, $request);

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        $resource = $result['resource'] ?? $result;
        $this->idempotency->storeResponse(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $idempotencyPayload,
            200,
            $resource,
            'asset.manage',
        );

        return response()->json($resource);
    }

    public function mix(Request $request): JsonResponse
    {
        return $this->read($request, 'stock.view', fn (): array => $this->operations->mix($request->query()));
    }

    public function updateMix(Request $request): JsonResponse
    {
        return $this->write(
            $request,
            'stock.generate',
            'admin.central.lottery-images.mix.update',
            fn (AdminSessionContext $context, array $payload): array => $this->operations->updateMix($payload, $context, $request),
        );
    }

    public function retryPending(Request $request): JsonResponse
    {
        return $this->write(
            $request,
            'stock.generate',
            'admin.central.lottery-images.retry-pending',
            fn (AdminSessionContext $context, array $payload): array => $this->operations->retryPending($payload),
            202,
        );
    }

    public function productionReadiness(Request $request): JsonResponse
    {
        return $this->read($request, 'stock.view', fn (): array => $this->operations->productionReadiness());
    }

    public function preview(Request $request): JsonResponse
    {
        return $this->read($request, 'stock.view', fn (): array => $this->operations->preview($request->all()));
    }

    public function layout(Request $request): JsonResponse
    {
        return $this->read($request, 'asset.manage', fn (): array => $this->operations->layout());
    }

    public function updateLayout(Request $request): JsonResponse
    {
        return $this->write(
            $request,
            'asset.manage',
            'admin.central.lottery-images.layout.update',
            fn (AdminSessionContext $context, array $payload): array => $this->operations->updateLayout($payload, $context, $request),
        );
    }

    private function read(Request $request, string $permissionCode, callable $callback): JsonResponse
    {
        $context = $this->authorizedContext($request, $permissionCode);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $callback();

        return $this->resultResponse($request, $result);
    }

    private function write(Request $request, string $permissionCode, string $routeKey, callable $callback, int $defaultStatus = 200): JsonResponse
    {
        $context = $this->authorizedContext($request, $permissionCode);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            $permissionCode,
            true,
        );

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $result = $callback($context, $payload);

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $status = (int) ($result['status'] ?? $defaultStatus);
        $resource = $result['resource'] ?? $result;

        $this->idempotency->storeResponse(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            $status,
            $resource,
            $permissionCode,
        );

        return response()->json($resource, $status);
    }

    private function resultResponse(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        return response()->json($result);
    }

    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== 'central') {
            return ApiErrorResponse::permissionDenied($request);
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
