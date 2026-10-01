<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Commerce\Http\Requests\CommerceRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerReservationController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly RequestHeaderValidator $headers,
        private readonly CommerceRequestValidator $validator,
    ) {
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $customer = $request->attributes->get('customer_session');

        if (! $customer instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($customer->tenantId() !== $tenant['tenant_id']) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->validator->reservationErrors($payload) + $this->partnerStore->validateReservationPayload($tenant['tenant_id'], $customer, $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->partnerStore->createReservation($tenant['tenant_id'], $tenant['partner_id'], $customer, $payload, $request);

        return $this->writeResult($request, $result, 201);
    }

    public function release(Request $request, string $reservation_id): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $customer = $request->attributes->get('customer_session');

        if (! $customer instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($customer->tenantId() !== $tenant['tenant_id']) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $result = $this->partnerStore->releaseReservation($tenant['tenant_id'], $tenant['partner_id'], $reservation_id, $customer, $request);

        return $this->writeResult($request, $result);
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    /**
     * @param array{resource?: array<string, mixed>|null, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $successStatus = 200): JsonResponse
    {
        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if (($result['error'] ?? null) === 'reservation_unavailable') {
            return ApiErrorResponse::reservationUnavailable($request);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'], $successStatus);
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): JsonResponse
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }
}
