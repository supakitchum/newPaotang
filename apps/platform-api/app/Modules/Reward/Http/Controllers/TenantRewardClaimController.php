<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Reward\Services\RewardService;
use App\Modules\Reward\Http\Requests\RewardClaimRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantRewardClaimController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly RewardService $rewards,
        private readonly RequestHeaderValidator $headers,
        private readonly RewardClaimRequestValidator $validator,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_claim.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->rewards->tenantClaims((string) $context->activeTenantId(), $request->query()));
    }

    public function show(Request $request, string $claim_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_claim.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $claim = $this->rewards->tenantClaim((string) $context->activeTenantId(), $claim_id);

        return $claim === null ? ApiErrorResponse::notFound($request) : response()->json($claim);
    }

    public function approve(Request $request, string $claim_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_claim.approve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->rewards->approveTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all(), $request),
            $this->validator->tenantClaimActionErrors($request->all(), 'approve'),
        );
    }

    public function reject(Request $request, string $claim_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_claim.reject');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->rewards->rejectTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all(), $request),
            $this->validator->tenantClaimActionErrors($request->all(), 'reject'),
        );
    }

    public function pay(Request $request, string $claim_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_claim.pay');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->rewards->payTenantClaim((string) $context->activeTenantId(), $context, $claim_id, $request->all(), $request),
            $this->validator->tenantClaimActionErrors($request->all(), 'pay'),
        );
    }

    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission($context->adminUser['id'], 'tenant', $context->activeScopeId(), $permissionCode, $context->activeTenantId())) {
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
            default => response()->json($result['resource'] ?? [], $result['status'] ?? 200),
        };
    }

}
