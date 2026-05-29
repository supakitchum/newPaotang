<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Reward\Services\RewardService;
use App\Modules\Reward\Http\Requests\RewardClaimRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerRewardController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly RewardService $rewards,
        private readonly RequestHeaderValidator $headers,
        private readonly RewardClaimRequestValidator $validator,
    ) {
    }

    public function ticketRewardStatus(Request $request, string $ticket_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $status = $this->rewards->ticketRewardStatus($tenant['tenant_id'], $customer, $ticket_id);

        return $status === null ? ApiErrorResponse::notFound($request) : response()->json($status);
    }

    public function claims(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->rewards->customerClaims($tenant['tenant_id'], $customer, $request->query()));
    }

    public function createClaim(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payloadErrors = $this->validator->customerClaimErrors($request->all());

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        return $this->writeResult($request, $this->rewards->createCustomerClaim($tenant['tenant_id'], $customer, $request->all(), $request), 201);
    }

    public function claim(Request $request, string $claim_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $claim = $this->rewards->customerClaim($tenant['tenant_id'], $customer, $claim_id);

        return $claim === null ? ApiErrorResponse::notFound($request) : response()->json($claim);
    }

    /**
     * @return array{0: array<string, mixed>, 1: CustomerSessionContext, 2: JsonResponse|null}
     */
    private function tenantCustomer(Request $request): array
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

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
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, retry_after_seconds?: int|null} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
            'validation_failed' => ApiErrorResponse::validationFailed($request, ['payload' => ['The request payload is invalid.']]),
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
