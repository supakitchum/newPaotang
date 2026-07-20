<?php

namespace App\Modules\CustomerNotifications\Http\Controllers;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantCustomerNotificationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CustomerNotificationService $notifications,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.view');
        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->adminList((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');
        if (! $context instanceof AdminSessionContext) return $context;

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) return ApiErrorResponse::validationFailed($request, $headerErrors);

        $tenantId = (string) $context->activeTenantId();
        $actorId = (string) $context->adminUser['id'];
        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            $tenantId,
            'tenant_admin',
            $actorId,
            'admin.tenant.customer-notifications.store',
            $idempotencyKey,
            $payload,
            'customer_notification.send',
            true,
        );

        if ($replay === 'idempotency_conflict') return ApiErrorResponse::idempotencyConflict($request);
        if ($replay === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);
        if (is_array($replay)) return response()->json($replay['body'], $replay['status']);

        $result = $this->notifications->sendFromAdmin($tenantId, $context, $payload, $request, $idempotencyKey);
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? []);
        }
        if (($result['error'] ?? null) === 'not_found') return ApiErrorResponse::notFound($request);

        $resource = $result['resource'] ?? [];
        $this->idempotency->storeResponse(
            $tenantId,
            'tenant_admin',
            $actorId,
            'admin.tenant.customer-notifications.store',
            $idempotencyKey,
            $payload,
            201,
            $resource,
            'customer_notification.send',
        );
        return response()->json($resource, 201);
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext) return ApiErrorResponse::authenticationRequired($request);
        if ($context->activeScope() !== 'tenant' || $context->activeTenantId() === null || $context->activeTenantId() === '') {
            return ApiErrorResponse::permissionDenied($request);
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
}
