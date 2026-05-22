<?php

namespace App\Modules\Growth\Http\Controllers;

use App\Modules\Growth\Services\GrowthService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerAffiliateController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly GrowthService $growth,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function overview(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->growth->customerAffiliateOverview($tenant['tenant_id'], $customer));
    }

    public function register(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'customer_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->growth->registerCustomerAffiliate($tenant['tenant_id'], $customer, $request->all(), $request), 201);
    }

    public function applyReferral(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'customer_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return $this->writeResult($request, $this->growth->applyCustomerReferral($tenant['tenant_id'], $customer, $request->all(), $request));
    }

    public function commissions(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->growth->customerAffiliateCommissions($tenant['tenant_id'], $customer, $request->query()));
    }

    public function payouts(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->growth->customerAffiliatePayouts($tenant['tenant_id'], $customer, $request->query()));
    }

    public function createPayout(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'payment_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->growth->createCustomerAffiliatePayout($tenant['tenant_id'], $customer, $request->all(), $request), 201);
    }

    /**
     * @return array{0: array<string, mixed>, 1: CustomerSessionContext, 2: JsonResponse|null}
     */
    private function tenantCustomer(Request $request, bool|string $blockMaintenance = true): array
    {
        $result = $this->partnerStore->tenantContextForRequest($request, $blockMaintenance);

        if (isset($result['error'])) {
            return [[], new CustomerSessionContext([], []), $this->tenantError($request, $result['error'])];
        }

        $customer = $request->attributes->get('customer_session');

        if (! $customer instanceof CustomerSessionContext) {
            return [[], new CustomerSessionContext([], []), ApiErrorResponse::authenticationRequired($request)];
        }

        if ($customer->tenantId() !== $result['context']['tenant_id']) {
            return [[], $customer, ApiErrorResponse::permissionDenied($request)];
        }

        return [$result['context'], $customer, null];
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
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
