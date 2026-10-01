<?php

namespace App\Modules\CentralStock\Http\Controllers;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use App\Modules\CentralStock\Services\PartnerLotteryBrandingAssetService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PartnerLotteryBrandingAssetController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly PartnerLotteryBrandingAssetService $brandingAssets,
        private readonly LotteryImageOperationsService $lotteryImages,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function show(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->brandingAssets->find($partner_id);

        return $resource === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($resource);
    }

    public function update(Request $request, string $partner_id): JsonResponse
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
        $routeKey = 'admin.central.partners.lottery-branding-assets:'.$partner_id;
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
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

        $result = $this->brandingAssets->upsert($partner_id, $payload, $context, $request);

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $resource = $result['resource'] ?? [];
        $this->idempotency->storeResponse(
            null,
            'central_admin',
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            200,
            $resource,
            'asset.manage',
        );

        return response()->json($resource);
    }

    public function preview(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $payload['mode'] = 'partner_branded';
        $result = $this->lotteryImages->preview($payload, $partner_id);

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        return response()->json($result);
    }

    private function authorizedContext(Request $request): AdminSessionContext|JsonResponse
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
            'asset.manage',
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
