<?php

namespace App\Modules\Activities\Http\Controllers;

use App\Modules\Activities\Services\TenantActivityService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerActivityController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly TenantActivityService $activities,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        return $error instanceof JsonResponse
            ? $error
            : response()->json($this->activities->customerActivities($tenant['tenant_id'], $customer, $request->query()));
    }

    public function show(Request $request, string $activity_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $activity = $this->activities->customerActivity($tenant['tenant_id'], $customer, $activity_id);

        return $activity === null ? ApiErrorResponse::notFound($request) : response()->json($activity);
    }

    public function rights(Request $request, string $activity_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $rights = $this->activities->customerRights($tenant['tenant_id'], $customer, $activity_id);

        return $rights === null ? ApiErrorResponse::notFound($request) : response()->json($rights);
    }

    public function storeEntry(Request $request, string $activity_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return $this->writeResult($request, $this->activities->createCustomerEntry($tenant['tenant_id'], $customer, $activity_id, $request->all()), 201);
    }

    public function awards(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        return $error instanceof JsonResponse
            ? $error
            : response()->json($this->activities->customerAwards($tenant['tenant_id'], $customer, $request->query()));
    }

    public function claims(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        return $error instanceof JsonResponse
            ? $error
            : response()->json($this->activities->customerClaims($tenant['tenant_id'], $customer, $request->query()));
    }

    public function claim(Request $request, string $claim_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $claim = $this->activities->customerClaim($tenant['tenant_id'], $customer, $claim_id);

        return $claim === null ? ApiErrorResponse::notFound($request) : response()->json($claim);
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

        return $this->writeResult($request, $this->activities->createCustomerClaim($tenant['tenant_id'], $customer, $request->all(), $request), 201);
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
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, retry_after_seconds?: int|null, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'activity_entry_closed' => ApiErrorResponse::make($request, 409, 'activity_entry_closed', 'Activity participation period has ended.'),
            'not_found' => ApiErrorResponse::notFound($request),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
            'pin_assertion_invalid' => ApiErrorResponse::make($request, 403, 'pin_assertion_invalid', 'The biometric PIN assertion is invalid or expired.'),
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
