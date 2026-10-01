<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerPasswordResetService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerPasswordResetController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly PermissionService $permissions,
        private readonly CustomerPasswordResetService $passwordResets,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function forgot(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $errors = $this->passwordResets->forgotPasswordErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->serviceResult($request, $this->passwordResets->requestReset($tenant, $request->all(), $request), 202);
    }

    public function reset(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $errors = $this->passwordResets->resetPasswordErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->serviceResult(
            $request,
            $this->passwordResets->resetPassword($request->all(), $request, (string) $tenant['tenant_id']),
        );
    }

    public function tenantIndex(Request $request): JsonResponse
    {
        $context = $this->tenantAdminContext($request, 'customer_password_reset.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->passwordResets->tenantRequests((string) $context->activeTenantId(), $request->query());

        return isset($result['error'])
            ? $this->serviceResult($request, $result)
            : response()->json($result);
    }

    public function tenantIssueLink(Request $request, string $request_id): JsonResponse
    {
        $context = $this->tenantAdminContext($request, 'customer_password_reset.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->serviceResult(
            $request,
            $this->passwordResets->issueAdminResetLink((string) $context->activeTenantId(), $request_id, $context, $request),
        );
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    private function tenantAdminContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
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

    /**
     * @param array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, mixed>, details?: array<string, mixed>} $result
     */
    private function serviceResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'permission_denied' => ApiErrorResponse::permissionDenied($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'storage_unavailable' => ApiErrorResponse::make(
                $request,
                503,
                'storage_unavailable',
                'Password reset storage is not ready. Please run database migrations.',
                $result['details'] ?? [],
            ),
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
