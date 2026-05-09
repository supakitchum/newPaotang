<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\TenantPaymentSettingsService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantPaymentSettingsController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantPaymentSettingsService $paymentSettings,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function settings(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $settings = $this->paymentSettings->settings((string) $context->activeTenantId());

        return $settings === null ? ApiErrorResponse::notFound($request) : response()->json($settings);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'admin.tenant.payment-settings.patch',
            'payment_settings.manage',
            fn (array $payload): array => $this->paymentSettings->updateSettings($tenantId, $payload, $context, $request),
        );
    }

    public function channels(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->paymentSettings->listChannels((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createChannel(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'admin.tenant.payment-channels.store',
            'payment_settings.manage',
            fn (array $payload): array => $this->paymentSettings->createChannel($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function showChannel(Request $request, string $payment_channel_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $channel = $this->paymentSettings->findChannel((string) $context->activeTenantId(), $payment_channel_id);

        return $channel === null ? ApiErrorResponse::notFound($request) : response()->json($channel);
    }

    public function updateChannel(Request $request, string $payment_channel_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'admin.tenant.payment-channels.patch:'.$payment_channel_id,
            'payment_settings.manage',
            fn (array $payload): array => $this->paymentSettings->updateChannel($tenantId, $payment_channel_id, $payload, $context, $request),
        );
    }

    public function destroyChannel(Request $request, string $payment_channel_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'payment_settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'admin.tenant.payment-channels.delete:'.$payment_channel_id,
            'payment_settings.manage',
            fn (array $payload): array => $this->paymentSettings->archiveChannel($tenantId, $payment_channel_id, $payload, $context, $request),
        );
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

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

    private function writeWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $tenantId,
        string $routeKey,
        string $permissionCode,
        callable $callback,
        int $defaultStatus = 200,
    ): JsonResponse {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $permissionCode, true);

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $result = $callback($payload);

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        $status = $result['status'] ?? $defaultStatus;
        $resource = $result['resource'] ?? [];

        $this->idempotency->storeResponse($tenantId, 'tenant_admin', (string) $context->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $resource, $permissionCode);

        return response()->json($resource, $status);
    }
}
