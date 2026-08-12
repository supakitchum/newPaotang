<?php

namespace App\Modules\CustomerNotifications\Http\Controllers;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerNotificationController extends Controller
{
    public function __construct(
        private readonly CustomerNotificationService $notifications,
        private readonly PartnerStoreService $partnerStore,
    ) {
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
        if (($result['error'] ?? null) === 'token_rotation_required') {
            return ApiErrorResponse::make(
                $request,
                409,
                'push_token_rotation_required',
                'The revoked push token must be replaced before this installation can register again.',
            );
        }
        if (($result['error'] ?? null) === 'installation_credential_invalid') {
            return ApiErrorResponse::make(
                $request,
                409,
                'push_installation_credential_invalid',
                'The push installation credential does not match this device.',
            );
        }
        return response()->json($result['resource'] ?? [], 201);
    }

    public function registerAnonymousInstallation(Request $request): JsonResponse
    {
        $tenant = $this->partnerStore->tenantContextForRequest($request, false);
        if (isset($tenant['error'])) {
            $error = $tenant['error'];

            return ApiErrorResponse::make(
                $request,
                (int) ($error['status'] ?? 404),
                (string) ($error['code'] ?? 'tenant_not_found'),
                (string) ($error['message'] ?? 'Tenant was not found.'),
            );
        }

        $result = $this->notifications->registerAnonymousInstallation(
            (string) $tenant['context']['tenant_id'],
            $request->all(),
        );
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? []);
        }
        if (($result['error'] ?? null) === 'token_rotation_required') {
            return ApiErrorResponse::make(
                $request,
                409,
                'push_token_rotation_required',
                'The revoked push token must be replaced before this installation can register again.',
            );
        }
        if (($result['error'] ?? null) === 'installation_credential_invalid') {
            return ApiErrorResponse::make(
                $request,
                409,
                'push_installation_credential_invalid',
                'The push installation credential does not match this device.',
            );
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

    public function detachDevice(Request $request, string $installation_id): JsonResponse
    {
        $context = $this->context($request);
        if (! $context instanceof CustomerSessionContext) return $context;

        return $this->notifications->detachDevice($context->tenantId(), $context->customerId(), $installation_id)
            ? response()->json([], 204)
            : ApiErrorResponse::notFound($request);
    }

    public function deviceStatus(Request $request, string $installation_id): JsonResponse
    {
        $context = $this->context($request);
        if (! $context instanceof CustomerSessionContext) return $context;

        return response()->json($this->notifications->deviceStatus(
            $context->tenantId(),
            $context->customerId(),
            $installation_id,
        ));
    }

    private function context(Request $request): CustomerSessionContext|JsonResponse
    {
        $context = $request->attributes->get('customer_session');
        return $context instanceof CustomerSessionContext ? $context : ApiErrorResponse::authenticationRequired($request);
    }
}
