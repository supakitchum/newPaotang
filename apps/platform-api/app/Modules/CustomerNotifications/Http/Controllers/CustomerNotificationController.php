<?php

namespace App\Modules\CustomerNotifications\Http\Controllers;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerNotificationController extends Controller
{
    public function __construct(private readonly CustomerNotificationService $notifications)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof CustomerSessionContext
            ? response()->json($this->notifications->customerList(
                $context->tenantId(),
                $context->customerId(),
                $request->query(),
                (string) $request->header('Accept-Language', 'th-TH'),
            ))
            : $context;
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof CustomerSessionContext
            ? response()->json(['unread_count' => $this->notifications->unreadCount($context->tenantId(), $context->customerId())])
            : $context;
    }

    public function markRead(Request $request, string $notification_id): JsonResponse
    {
        $context = $this->context($request);
        if (! $context instanceof CustomerSessionContext) return $context;

        $resource = $this->notifications->markRead(
            $context->tenantId(),
            $context->customerId(),
            $notification_id,
            (string) $request->header('Accept-Language', 'th-TH'),
        );
        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof CustomerSessionContext
            ? response()->json($this->notifications->markAllRead($context->tenantId(), $context->customerId()))
            : $context;
    }

    public function registerDevice(Request $request): JsonResponse
    {
        $context = $this->context($request);
        if (! $context instanceof CustomerSessionContext) return $context;

        $result = $this->notifications->registerDevice($context->tenantId(), $context->customerId(), $request->all());
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? []);
        }
        return response()->json($result['resource'] ?? [], 201);
    }

    public function revokeDevice(Request $request, string $installation_id): JsonResponse
    {
        $context = $this->context($request);
        if (! $context instanceof CustomerSessionContext) return $context;

        return $this->notifications->revokeDevice($context->tenantId(), $context->customerId(), $installation_id)
            ? response()->json([], 204)
            : ApiErrorResponse::notFound($request);
    }

    private function context(Request $request): CustomerSessionContext|JsonResponse
    {
        $context = $request->attributes->get('customer_session');
        return $context instanceof CustomerSessionContext ? $context : ApiErrorResponse::authenticationRequired($request);
    }
}
