<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantReservationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly PartnerStoreService $partnerStore,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reservation.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->partnerStore->listReservations((string) $context->activeTenantId(), $request->query()));
    }

    public function show(Request $request, string $reservation_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reservation.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $reservation = $this->partnerStore->adminReservation((string) $context->activeTenantId(), $reservation_id);

        if ($reservation === null) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($reservation);
    }

    public function cancel(Request $request, string $reservation_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reservation.cancel');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $tenantId = (string) $context->activeTenantId();
        $partnerId = $this->partnerStore->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return ApiErrorResponse::notFound($request);
        }

        $result = $this->partnerStore->cancelReservation($tenantId, $partnerId, $reservation_id, $context, $request->all(), $request);

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource']);
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
}
