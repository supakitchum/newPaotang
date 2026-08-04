<?php

namespace App\Modules\CustomerNotifications\Http\Controllers;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\CustomerNotifications\Services\CustomerCommunicationCampaignService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantCustomerNotificationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CustomerNotificationService $notifications,
        private readonly CustomerCommunicationCampaignService $campaigns,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.view');
        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->adminList((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function customers(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->adminCustomerOptions((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');
        if (! $context instanceof AdminSessionContext) return $context;

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) return ApiErrorResponse::validationFailed($request, $headerErrors);

        $tenantId = (string) $context->activeTenantId();
        $actorId = (string) $context->adminUser['id'];
        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            $tenantId,
            'tenant_admin',
            $actorId,
            'admin.tenant.customer-notifications.store',
            $idempotencyKey,
            $payload,
            'customer_notification.send',
            true,
        );

        if ($replay === 'idempotency_conflict') return ApiErrorResponse::idempotencyConflict($request);
        if ($replay === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);
        if (is_array($replay)) return response()->json($replay['body'], $replay['status']);

        $result = $this->notifications->sendFromAdmin($tenantId, $context, $payload, $request, $idempotencyKey);
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? []);
        }
        if (($result['error'] ?? null) === 'not_found') return ApiErrorResponse::notFound($request);

        $resource = $result['resource'] ?? [];
        $this->idempotency->storeResponse(
            $tenantId,
            'tenant_admin',
            $actorId,
            'admin.tenant.customer-notifications.store',
            $idempotencyKey,
            $payload,
            201,
            $resource,
            'customer_notification.send',
        );
        return response()->json($resource, 201);
    }

    public function campaigns(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->campaigns->list((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function storeCampaign(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');
        if (! $context instanceof AdminSessionContext) return $context;

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) return ApiErrorResponse::validationFailed($request, $headerErrors);

        $payload = $this->campaignPayload($request);
        $fingerprintPayload = $payload;
        if (($file = $request->file('file')) !== null) {
            $fingerprintPayload['_image'] = [
                'name' => $file->getClientOriginalName(),
                'size' => (int) $file->getSize(),
                'sha256' => hash_file('sha256', $file->getRealPath()) ?: null,
            ];
        }
        $tenantId = (string) $context->activeTenantId();
        $actorId = (string) $context->adminUser['id'];
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $routeKey = 'admin.tenant.customer-communications.store';
        $replay = $this->idempotency->replayOrConflict(
            $tenantId,
            'tenant_admin',
            $actorId,
            $routeKey,
            $idempotencyKey,
            $fingerprintPayload,
            'customer_notification.send',
            true,
        );
        if ($replay === 'idempotency_conflict') return ApiErrorResponse::idempotencyConflict($request);
        if ($replay === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);
        if (is_array($replay)) return response()->json($replay['body'], $replay['status']);

        $result = $this->campaigns->create($tenantId, $context, $payload, $request->file('file'), $request, $idempotencyKey);
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? []);
        }
        if (($result['error'] ?? null) === 'not_found') return ApiErrorResponse::notFound($request);
        if (($result['error'] ?? null) === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);

        $resource = $result['resource'] ?? [];
        $this->idempotency->storeResponse(
            $tenantId,
            'tenant_admin',
            $actorId,
            $routeKey,
            $idempotencyKey,
            $fingerprintPayload,
            201,
            $resource,
            'customer_notification.send',
        );

        return response()->json($resource, 201);
    }

    public function publishCampaign(Request $request, string $campaign_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');
        if (! $context instanceof AdminSessionContext) return $context;

        return $this->mutateCampaign($request, $context, $campaign_id, 'publish');
    }

    public function cancelCampaign(Request $request, string $campaign_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer_notification.send');
        if (! $context instanceof AdminSessionContext) return $context;

        return $this->mutateCampaign($request, $context, $campaign_id, 'cancel');
    }

    /** @return array<string, mixed> */
    private function campaignPayload(Request $request): array
    {
        $encoded = $request->input('payload');
        if (is_string($encoded) && trim($encoded) !== '') {
            $decoded = json_decode($encoded, true);
            return is_array($decoded) ? $decoded : [];
        }

        return $request->except('file');
    }

    /** @param array<string, mixed> $result */
    private function campaignMutationResponse(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'not_found') return ApiErrorResponse::notFound($request);
        if (($result['error'] ?? null) === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);

        return response()->json($result['resource'] ?? []);
    }

    private function mutateCampaign(
        Request $request,
        AdminSessionContext $context,
        string $campaignId,
        string $action,
    ): JsonResponse {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) return ApiErrorResponse::validationFailed($request, $headerErrors);

        $tenantId = (string) $context->activeTenantId();
        $actorId = (string) $context->adminUser['id'];
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $routeKey = 'admin.tenant.customer-communications.'.$action;
        $fingerprint = ['campaign_id' => $campaignId, 'action' => $action];
        $replay = $this->idempotency->replayOrConflict(
            $tenantId,
            'tenant_admin',
            $actorId,
            $routeKey,
            $idempotencyKey,
            $fingerprint,
            'customer_notification.send',
            true,
        );
        if ($replay === 'idempotency_conflict') return ApiErrorResponse::idempotencyConflict($request);
        if ($replay === 'resource_conflict') return ApiErrorResponse::resourceConflict($request);
        if (is_array($replay)) return response()->json($replay['body'], $replay['status']);

        $result = $action === 'publish'
            ? $this->campaigns->publishNow($tenantId, $campaignId, $context, $request)
            : $this->campaigns->cancel($tenantId, $campaignId, $context, $request);
        $response = $this->campaignMutationResponse($request, $result);
        if ($response->getStatusCode() >= 400) return $response;

        $resource = $result['resource'] ?? [];
        $this->idempotency->storeResponse(
            $tenantId,
            'tenant_admin',
            $actorId,
            $routeKey,
            $idempotencyKey,
            $fingerprint,
            200,
            $resource,
            'customer_notification.send',
        );

        return response()->json($resource);
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext) return ApiErrorResponse::authenticationRequired($request);
        if ($context->activeScope() !== 'tenant' || $context->activeTenantId() === null || $context->activeTenantId() === '') {
            return ApiErrorResponse::permissionDenied($request);
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
