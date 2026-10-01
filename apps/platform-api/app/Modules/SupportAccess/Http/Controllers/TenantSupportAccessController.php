<?php

namespace App\Modules\SupportAccess\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\SupportAccess\Services\SupportAccessService;
use App\Modules\SupportAccess\Http\Requests\SupportAccessRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantSupportAccessController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly SupportAccessService $supportAccess,
        private readonly RequestHeaderValidator $headers,
        private readonly SupportAccessRequestValidator $validator,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.audit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->filterErrors($request->query());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json($this->supportAccess->listRequests((string) $context->activeTenantId(), $request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.request');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $guard = $this->validateWrite($request, $context, $request->all(), $this->validator->supportCreateErrors((string) $context->activeTenantId(), $request->all()));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        $payload = $request->all();

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.create',
            'support_access.request',
            $payload,
            fn (): array|string => $this->supportAccess->createRequest((string) $context->activeTenantId(), $payload, $context, $request),
            201,
        );
    }

    public function show(Request $request, string $support_access_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.audit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->supportAccess->findRequest((string) $context->activeTenantId(), $support_access_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function approve(Request $request, string $support_access_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.approve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $guard = $this->validateWrite($request, $context, $payload, $this->validator->reasonErrors($payload));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.approve.'.$support_access_id,
            'support_access.approve',
            $payload + ['support_access_id' => $support_access_id],
            fn (): array|string => $this->supportAccess->approve((string) $context->activeTenantId(), $support_access_id, $payload, $context, $request),
        );
    }

    public function revoke(Request $request, string $support_access_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.approve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $guard = $this->validateWrite($request, $context, $payload, $this->validator->reasonErrors($payload));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.revoke.'.$support_access_id,
            'support_access.approve',
            $payload + ['support_access_id' => $support_access_id],
            fn (): array|string => $this->supportAccess->revoke((string) $context->activeTenantId(), $support_access_id, $payload, $context, $request),
        );
    }

    public function impersonate(Request $request, string $support_access_id): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $supportRequest = $this->supportAccess->findRequest((string) $context->activeTenantId(), $support_access_id);

        if ($supportRequest === null) {
            return ApiErrorResponse::notFound($request);
        }

        $permission = $supportRequest['target_user_type'] === 'tenant_admin'
            ? 'support_access.impersonate_admin'
            : 'support_access.impersonate_customer';
        $permissionContext = $this->authorizedContext($request, $permission);

        if (! $permissionContext instanceof AdminSessionContext) {
            return $permissionContext;
        }

        $payload = $request->all();
        $guard = $this->validateWrite($request, $context, $payload, $this->validator->reasonErrors($payload));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.impersonate.'.$support_access_id,
            $permission,
            $payload + ['support_access_id' => $support_access_id],
            function () use ($context, $support_access_id, $payload, $request): array|string {
                $result = $this->supportAccess->startImpersonation((string) $context->activeTenantId(), $support_access_id, $payload, $context, $request);

                return $result['error'] ?? $result['resource'] ?? 'resource_conflict';
            },
            200,
            fn (array $body): array => $this->withoutInitialToken($body),
        );
    }

    public function elevatedAction(Request $request, string $support_access_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.elevated_action');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $guard = $this->validateWrite($request, $context, $payload, $this->validator->elevatedActionErrors($payload));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.elevated_action.'.$support_access_id,
            'support_access.elevated_action',
            $payload + ['support_access_id' => $support_access_id],
            fn (): array|string => $this->supportAccess->recordElevatedAction((string) $context->activeTenantId(), $support_access_id, $payload, $context, $request),
            202,
        );
    }

    public function endSession(Request $request, string $support_access_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'support_access.audit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $payload = $request->all();
        $guard = $this->validateWrite($request, $context, $payload, $this->validator->reasonErrors($payload));

        if ($guard instanceof JsonResponse) {
            return $guard;
        }

        return $this->jsonWriteWithIdempotency(
            $request,
            $context,
            'tenant.support_access.end_session.'.$support_access_id,
            'support_access.audit',
            $payload + ['support_access_id' => $support_access_id],
            fn (): array|string => $this->supportAccess->endSession((string) $context->activeTenantId(), $support_access_id, $payload, $context, $request),
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
     * @param array<string, mixed> $payload
     * @param array<string, array<int, string>> $payloadErrors
     */
    private function validateWrite(Request $request, AdminSessionContext $context, array $payload, array $payloadErrors): ?JsonResponse
    {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        if ($context->activeTenantId() === null) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return null;
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array<string, mixed>|string $callback
     * @param callable(array<string, mixed>): array<string, mixed>|null $sanitizeForReplay
     */
    private function jsonWriteWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        string $routeKey,
        string $permissionCode,
        array $payload,
        callable $callback,
        int $successStatus = 200,
        ?callable $sanitizeForReplay = null,
    ): JsonResponse {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $tenantId = (string) $context->activeTenantId();
        $actorId = (string) $context->adminUser['id'];
        $replay = $this->idempotency->replayOrConflict($tenantId, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, $permissionCode);

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        $result = $callback();

        if ($result === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        if ($result === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if ($result === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        $stored = $sanitizeForReplay === null ? $result : $sanitizeForReplay($result);
        $this->idempotency->storeResponse($tenantId, 'admin', $actorId, $routeKey, $idempotencyKey, $payload, $successStatus, $stored, $permissionCode);

        return response()->json($result, $successStatus);
    }

    /**
     * @param array<string, mixed> $body
     * @return array<string, mixed>
     */
    private function withoutInitialToken(array $body): array
    {
        if (isset($body['active_session']) && is_array($body['active_session'])) {
            unset($body['active_session']['access_token']);
        }

        return $body;
    }
}
