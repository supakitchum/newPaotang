<?php

namespace App\Modules\LineNotifications\Http\Controllers;

use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerLineNotificationController extends Controller
{
    public function __construct(private readonly TenantLineNotificationService $notifications)
    {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? response()->json($this->notifications->customerSettings($context->tenantId(), $context->customerId()))
            : $context;
    }

    public function update(Request $request): JsonResponse
    {
        $context = $this->context($request);

        if (! $context instanceof CustomerSessionContext) {
            return $context;
        }

        $result = $this->notifications->updateCustomerSettings($context->tenantId(), $context->customerId(), $request->all());

        return $this->writeResult($request, $result);
    }

    public function disconnect(Request $request): JsonResponse
    {
        $context = $this->context($request);

        if (! $context instanceof CustomerSessionContext) {
            return $context;
        }

        $result = $this->notifications->disconnectCustomer($context->tenantId(), $context->customerId());

        return response()->json($result['resource'] ?? []);
    }

    private function context(Request $request): CustomerSessionContext|JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        return $context instanceof CustomerSessionContext
            ? $context
            : ApiErrorResponse::authenticationRequired($request);
    }

    private function writeResult(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'] ?? []);
    }
}
