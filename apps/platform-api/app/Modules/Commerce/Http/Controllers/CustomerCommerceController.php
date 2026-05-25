<?php

namespace App\Modules\Commerce\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Modules\Commerce\Services\CommerceService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Commerce\Http\Requests\CommerceRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerCommerceController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly CommerceService $commerce,
        private readonly RequestHeaderValidator $headers,
        private readonly CommerceRequestValidator $validator,
    ) {
    }

    public function cart(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $this->partnerStore->expireCustomerReservations($tenant['tenant_id'], $customer->customerId());

        return response()->json($this->commerce->cartForCustomer($tenant['tenant_id'], $customer));
    }

    public function checkout(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $errors = $this->headers->idempotencyKeyErrors($request) + $this->validator->checkoutErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->commerce->checkout($tenant, $customer, $request->all(), $request), 201);
    }

    public function wallet(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->commerce->walletsForCustomer($tenant['tenant_id'], $customer));
    }

    public function order(Request $request, string $order_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'customer_read');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $order = $this->commerce->customerOrder($tenant['tenant_id'], $customer, $order_id);

        return $order === null ? ApiErrorResponse::notFound($request) : response()->json($order);
    }

    public function tickets(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->commerce->customerTickets($tenant['tenant_id'], $customer, $request->query()));
    }

    public function ticketHistory(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->commerce->customerTickets($tenant['tenant_id'], $customer, $request->query(), true));
    }

    public function ticket(Request $request, string $ticket_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request);

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $ticket = $this->commerce->customerTicket($tenant['tenant_id'], $customer, $ticket_id);

        return $ticket === null ? ApiErrorResponse::notFound($request) : response()->json($ticket);
    }

    public function topups(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'customer_read');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        return response()->json($this->commerce->customerTopups($tenant['tenant_id'], $customer, $request->query()));
    }

    public function createTopup(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'payment_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $slipFile = $request->file('slip');
        $payloadErrors = $this->validator->customerTopupErrors($request->all())
            + $this->validator->topupSlipErrors($slipFile instanceof \Illuminate\Http\UploadedFile ? $slipFile : null);

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        return $this->writeResult($request, $this->commerce->createCustomerTopup($tenant['tenant_id'], $customer, $request->all(), $request), 201);
    }

    public function createCreditTopup(Request $request): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'payment_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $slipFile = $request->file('slip');
        $payloadErrors = $this->validator->customerTopupErrors($request->all(), true)
            + $this->validator->topupSlipErrors($slipFile instanceof \Illuminate\Http\UploadedFile ? $slipFile : null);

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        return $this->writeResult($request, $this->commerce->createCustomerTopup($tenant['tenant_id'], $customer, $request->all(), $request, true), 201);
    }

    public function topup(Request $request, string $topup_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'customer_read');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $topup = $this->commerce->customerTopup($tenant['tenant_id'], $customer, $topup_id);

        return $topup === null ? ApiErrorResponse::notFound($request) : response()->json($topup);
    }

    public function uploadTopupSlip(Request $request, string $topup_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'payment_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $slipFile = $request->file('slip');
        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->validator->requiredTopupSlipErrors($slipFile instanceof \Illuminate\Http\UploadedFile ? $slipFile : null);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->commerce->uploadCustomerTopupSlip($tenant['tenant_id'], $customer, $topup_id, $request->all(), $request));
    }

    public function cancelTopup(Request $request, string $topup_id): JsonResponse
    {
        [$tenant, $customer, $error] = $this->tenantCustomer($request, 'payment_write');

        if ($error instanceof JsonResponse) {
            return $error;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->commerce->cancelCustomerTopup($tenant['tenant_id'], $customer, $topup_id, $request->all(), $request));
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
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'reservation_unavailable' => ApiErrorResponse::reservationUnavailable($request),
            'reservation_expired' => ApiErrorResponse::reservationExpired($request),
            'wallet_insufficient_balance' => ApiErrorResponse::walletInsufficientBalance($request),
            'not_found' => ApiErrorResponse::notFound($request),
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
