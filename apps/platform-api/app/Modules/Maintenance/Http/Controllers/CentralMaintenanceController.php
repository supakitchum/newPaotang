<?php

namespace App\Modules\Maintenance\Http\Controllers;

use App\Modules\Maintenance\Http\Requests\MaintenanceRequestValidator;
use App\Modules\Maintenance\Services\MaintenanceService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralMaintenanceController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly MaintenanceService $maintenance,
        private readonly RequestHeaderValidator $headers,
        private readonly MaintenanceRequestValidator $validator,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->filterErrors($request->query(), false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->maintenance->centralTenantMaintenanceList($request->query()));
    }

    public function show(Request $request, string $tenant_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $setting = $this->maintenance->settingForTenant($tenant_id);

        return $setting === null ? ApiErrorResponse::notFound($request) : response()->json($setting);
    }

    public function partnerShow(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $setting = $this->maintenance->settingForPartner($partner_id);

        return $setting === null ? ApiErrorResponse::notFound($request) : response()->json($setting);
    }

    public function update(Request $request, string $tenant_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->validator->maintenanceUpdateErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            $tenant_id,
            'central.maintenance.update',
            'partner.update',
            $payload,
            fn (): array|string|null => $this->maintenance->updateSetting($tenant_id, $payload, $context, $request),
        );
    }

    public function partnerUpdate(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->validator->partnerMaintenanceUpdateErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->jsonWriteWithCentralPartnerIdempotency(
            $request,
            $context,
            $partner_id,
            $payload,
            fn (): array|string|null => $this->maintenance->updatePartnerSetting($partner_id, $payload, $context, $request),
        );
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

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array<string, mixed>|string|null $callback
     */
    private function jsonWriteWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $tenantId,
        string $routeKey,
        string $permissionCode,
        array $payload,
        callable $callback,
    ): JsonResponse {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $actorId = (string) $context->adminUser['id'];
        $replay = $this->idempotency->replayOrConflict($tenantId, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, $permissionCode);

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        $result = $callback();

        if ($result === null || $result === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if ($result === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $this->idempotency->storeResponse($tenantId, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, 200, $result, $permissionCode);

        return response()->json($result);
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array<string, mixed>|string|null $callback
     */
    private function jsonWriteWithCentralPartnerIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $partnerId,
        array $payload,
        callable $callback,
    ): JsonResponse {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $actorId = (string) $context->adminUser['id'];
        $routeKey = 'central.partner_maintenance.update.'.$partnerId;
        $replay = $this->idempotency->replayOrConflict(null, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, 'partner.update');

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        $result = $callback();

        if ($result === null || $result === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if ($result === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $this->idempotency->storeResponse(null, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, 200, $result, 'partner.update');

        return response()->json($result);
    }
}
