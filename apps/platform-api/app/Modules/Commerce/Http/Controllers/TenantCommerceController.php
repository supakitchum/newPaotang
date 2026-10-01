<?php

namespace App\Modules\Commerce\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Commerce\Services\CommerceService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Commerce\Http\Requests\CommerceRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantCommerceController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CommerceService $commerce,
        private readonly RequestHeaderValidator $headers,
        private readonly CommerceRequestValidator $validator,
    ) {
    }

    public function orders(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'order.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->commerce->adminOrders((string) $context->activeTenantId(), $request->query()));
    }

    public function order(Request $request, string $order_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'order.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $order = $this->commerce->adminOrder((string) $context->activeTenantId(), $order_id);

        return $order === null ? ApiErrorResponse::notFound($request) : response()->json($order);
    }

    public function updateOrder(Request $request, string $order_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'order.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->updateAdminOrder((string) $context->activeTenantId(), $context, $order_id, $request->all(), $request),
            $this->validator->updateOrderErrors($request->all()),
        );
    }

    public function cancelOrder(Request $request, string $order_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'order.cancel');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->cancelAdminOrder((string) $context->activeTenantId(), $context, $order_id, $request->all(), $request),
            $this->validator->cancelOrderErrors($request->all()),
        );
    }

    public function refundOrder(Request $request, string $order_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'order.refund');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->refundAdminOrder((string) $context->activeTenantId(), $context, $order_id, $request->all(), $request),
            $this->validator->refundOrderErrors($request->all()),
        );
    }

    public function tickets(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'ticket.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->commerce->adminTickets((string) $context->activeTenantId(), $request->query()));
    }

    public function ticket(Request $request, string $ticket_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'ticket.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $ticket = $this->commerce->adminTicket((string) $context->activeTenantId(), $ticket_id);

        return $ticket === null ? ApiErrorResponse::notFound($request) : response()->json($ticket);
    }

    public function wallets(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'wallet.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->commerce->adminWallets((string) $context->activeTenantId(), $request->query()));
    }

    public function wallet(Request $request, string $wallet_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'wallet.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $wallet = $this->commerce->adminWallet((string) $context->activeTenantId(), $wallet_id);

        return $wallet === null ? ApiErrorResponse::notFound($request) : response()->json($wallet);
    }

    public function walletLedger(Request $request, string $wallet_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'wallet.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $ledger = $this->commerce->adminWalletLedger((string) $context->activeTenantId(), $wallet_id, $request->query());

        return $ledger === null ? ApiErrorResponse::notFound($request) : response()->json($ledger);
    }

    public function adjustWallet(Request $request, string $wallet_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'wallet.adjust');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->adjustAdminWallet((string) $context->activeTenantId(), $context, $wallet_id, $request->all(), $request),
            $this->validator->walletAdjustmentErrors($request->all()),
        );
    }

    public function topups(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'topup.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->commerce->adminTopups((string) $context->activeTenantId(), $request->query()));
    }

    public function topup(Request $request, string $topup_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'topup.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $topup = $this->commerce->adminTopup((string) $context->activeTenantId(), $topup_id);

        return $topup === null ? ApiErrorResponse::notFound($request) : response()->json($topup);
    }

    public function approveTopup(Request $request, string $topup_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'topup.approve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->approveAdminTopup((string) $context->activeTenantId(), $context, $topup_id, $request->all(), $request),
            $this->validator->optionalReasonErrors($request->all()),
        );
    }

    public function rejectTopup(Request $request, string $topup_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'topup.reject');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->rejectAdminTopup((string) $context->activeTenantId(), $context, $topup_id, $request->all(), $request),
            $this->validator->reviewReasonErrors($request->all()),
        );
    }

    public function cancelTopup(Request $request, string $topup_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'topup.cancel');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->commerce->cancelAdminTopup((string) $context->activeTenantId(), $context, $topup_id, $request->all(), $request),
            $this->validator->optionalReasonErrors($request->all()),
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
     * @param callable(): array{resource?: array<string, mixed>|null, status?: int, error?: string} $callback
     * @param array<string, array<int, string>> $payloadErrors
     */
    private function writeWithIdempotency(Request $request, callable $callback, array $payloadErrors = []): JsonResponse
    {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        $result = $callback();

        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed(
                $request,
                $result['errors'] ?? ['payload' => ['The request payload is invalid.']],
            ),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? 200),
        };
    }
}
