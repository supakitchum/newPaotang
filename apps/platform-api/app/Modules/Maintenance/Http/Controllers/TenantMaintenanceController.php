<?php

namespace App\Modules\Maintenance\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use App\Modules\Maintenance\Services\MaintenanceService;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Maintenance\Http\Requests\MaintenanceRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class TenantMaintenanceController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly MaintenanceService $maintenance,
        private readonly RequestHeaderValidator $headers,
        private readonly MaintenanceRequestValidator $validator,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'maintenance.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $setting = $this->maintenance->settingForTenant((string) $context->activeTenantId());

        return $setting === null ? ApiErrorResponse::notFound($request) : response()->json($setting);
    }

    public function update(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'maintenance.update');

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

        if (($payload['status'] ?? null) === 'scheduled') {
            $scheduleContext = $this->authorizedContext($request, 'maintenance.schedule');

            if (! $scheduleContext instanceof AdminSessionContext) {
                return $scheduleContext;
            }
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.maintenance.update',
            'maintenance.update',
            $payload,
            fn (): array|string|null => $this->maintenance->updateSetting((string) $context->activeTenantId(), $payload, $context, $request),
        );
    }

    public function events(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'maintenance.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->filterErrors($request->query(), false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->maintenance->eventsForTenant((string) $context->activeTenantId(), $request->query()));
    }

    public function bypasses(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'maintenance.bypass');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->maintenanceBypassFilterErrors($request->query());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->maintenance->bypassesForTenant((string) $context->activeTenantId(), $request->query()));
    }

    public function createBypass(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'maintenance.bypass');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->validator->maintenanceBypassCreateErrors((string) $context->activeTenantId(), $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.maintenance.bypass.create',
            'maintenance.bypass',
            $payload,
            fn (): array|string => $this->maintenance->createBypass((string) $context->activeTenantId(), $payload, $context, $request),
            201,
        );
    }

    public function revokeBypass(Request $request, string $bypass_id): Response
    {
        $context = $this->authorizedContext($request, 'maintenance.bypass');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = ['bypass_id' => $bypass_id];
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            (string) $context->activeTenantId(),
            'admin',
            (string) $context->adminUser['id'],
            'tenant.maintenance.bypass.revoke',
            $idempotencyKey,
            $payload,
            'maintenance.bypass',
        );

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if (is_array($replay)) {
            return response()->noContent();
        }

        if (! $this->maintenance->revokeBypass((string) $context->activeTenantId(), $bypass_id, $context, $request)) {
            return ApiErrorResponse::notFound($request);
        }

        $this->idempotency->storeResponse(
            (string) $context->activeTenantId(),
            'admin',
            (string) $context->adminUser['id'],
            'tenant.maintenance.bypass.revoke',
            $idempotencyKey,
            $payload,
            204,
            null,
            'maintenance.bypass',
        );

        return response()->noContent();
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

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array<string, mixed>|string|null $callback
     */
    private function jsonWriteWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $routeKey,
        string $permissionCode,
        array $payload,
        callable $callback,
        int $successStatus = 200,
    ): JsonResponse {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $tenantId = (string) $context->activeTenantId();
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

        if ($result === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        $this->idempotency->storeResponse($tenantId, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, $successStatus, $result, $permissionCode);

        return response()->json($result, $successStatus);
    }
}
